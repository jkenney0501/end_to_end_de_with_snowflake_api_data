/**************************************************************************************************
Summmary:

This step loads the data for each hour manually to the internal stage "raw_stg".

From here a task is set up to run every hour to mimick the API data loading every hour.

The task will load the raw data from the interanl stage in to the raw_aql table in a format that is 
readable but also adds a few audit columns for file/file location and load time.

From here, the clean layer will flatten the data out and prepare it for consumption.


***** Snowflake interview questions:*****

-- could you explain the metadata properties: referneces location,  if loaded or skipped and compression /format used.
-- why should you use metadata properties: audit purposes. Monitor schema, table properties, and storage usage. Timestamp shows load date.
-- how these metadata properties helps you: 
-- the table naming convention while building: use the same acrsoss the board. meta uses _ as a prefix.
-- 16Mb limitations:


****** Understanding Pseudocolumns
What Are Pseudocolumns?: They are special columns provided by Snowflake that contain metadata about the data 
files being queried.

Common Pseudocolumns:
METADATA$FILENAME: Name of the source file.
METADATA$FILE_ROW_NUMBER: Row number within the source file.
METADATA$ROW_COUNT: Total number of rows in the source file.
METADATA$FILE_LAST_MODIFIED: Timestamp of the last modification of the source file.
METADATA$FILE_SIZE: Size of the source file in bytes.

*****************************************************************************************************/

-- change context
use schema dev_db.stage_sch;
use warehouse adhoc_wh;


-- create an internal stage and enable directory service
create stage if not exists raw_stg
directory = ( enable = true)
comment = 'all the air quality raw data will store in this internal stage location';


 -- create file format to process the JSON file given we are pulling api data that retiurns json files.
create file format if not exists json_file_format 
type = 'JSON'
compression = 'AUTO' 
comment = 'this is json file format object';

-- view stage
show stages;
list @raw_stg;



-- load the data that has been downloaded manually
-- run the list command to check it
list @raw_stg;



-- the queries below are just testing the json data by querying it directly from the file in the stage.
-- level-1, apply file format to be able to query the data directly from the stage
select 

    * 
from 
    @dev_db.stage_sch.raw_stg
    (file_format => JSON_FILE_FORMAT) t;



  -- JSON file analysis using json editor - query the data
  -- level-2
    select 
        Try_TO_TIMESTAMP(t.$1:records[0].last_update::text, 'dd-mm-yyyy hh24:mi:ss') as index_record_ts,
        t.$1,
        t.$1:total::int as record_count,
        t.$1:version::text as json_version  
    from @dev_db.stage_sch.raw_stg
    (file_format => JSON_FILE_FORMAT) t;



-- level3
select 
    Try_TO_TIMESTAMP(t.$1:records[0].last_update::text, 'dd-mm-yyyy hh24:mi:ss') as index_record_ts,
    t.$1,
    t.$1:total::int as record_count,
    t.$1:version::text as json_version,

    -- meta data information for files (always goes in stage)
    metadata$filename as _stg_file_name,
    metadata$FILE_LAST_MODIFIED as _stg_file_load_ts,
    metadata$FILE_CONTENT_KEY as _stg_file_md5,
    current_timestamp() as _copy_data_ts

from @dev_db.stage_sch.raw_stg
(file_format => JSON_FILE_FORMAT) t;



-- creating a raw table to have air quality data
create or replace transient table raw_aqi (
    id int primary key autoincrement,
    index_record_ts timestamp not null,
    json_data variant not null, -- this is the json data that we will clean later
    record_count number not null default 0,
    json_version text not null,
    -- audit columns for debugging
    _stg_file_name text,
    _stg_file_load_ts timestamp,
    _stg_file_md5 text,
    _copy_data_ts timestamp default current_timestamp()
);

-- see table metadata
describe table raw_aqi;

-- Questions for thought:
-- should you create transient table or permanent table? if so why?
-- how the standard table cost more with fail safe concept?



-- copy command
-- following copy command will query the stage directly on an automated cron job. From here it will load it to a stage raw_aqi with the added metadata columns.
create or replace task copy_air_quality_data
    warehouse = load_wh
    schedule = 'USING CRON */5 * * * * Asia/Kolkata'  -- set to run every 5 minutes given there are 24 files, one for every hour. This load is all at once b/s manual load.
as
copy into raw_aqi (index_record_ts,json_data,record_count,json_version,_stg_file_name,_stg_file_load_ts,_stg_file_md5,_copy_data_ts) from 
(
    select 
        Try_TO_TIMESTAMP(t.$1:records[0].last_update::text, 'dd-mm-yyyy hh24:mi:ss') as index_record_ts,
        t.$1,
        t.$1:total::int as record_count,
        t.$1:version::text as json_version,
        metadata$filename as _stg_file_name,
        metadata$FILE_LAST_MODIFIED as _stg_file_load_ts,
        metadata$FILE_CONTENT_KEY as _stg_file_md5,
        current_timestamp() as _copy_data_ts
            
   from @dev_db.stage_sch.raw_stg as t
)
file_format = (format_name = 'dev_db.stage_sch.JSON_FILE_FORMAT') 
ON_ERROR = ABORT_STATEMENT; 

show tasks; -- starts in suspend mode


--use role accountadmin;
--grant execute task, execute managed task on account to role sysadmin;
--use role sysadmin;

alter task dev_db.stage_sch.copy_air_quality_data resume;

-- check the data
select *
    from raw_aqi
    limit 10;

-- select with ranking to prpepare to eliminate dups in clean layer
select 
    index_record_ts,record_count,
    json_version,_stg_file_name,
    _stg_file_load_ts,
    _stg_file_md5,
    _copy_data_ts,
    row_number() over (partition by index_record_ts order by _stg_file_load_ts desc) as latest_file_rank  -- thiss will guard against duplicates
from raw_aqi 
order by index_record_ts desc
limit 10;

-- suspend after initial load given 24 files are loaded at once since they are all in the stage
alter task dev_db.stage_sch.copy_air_quality_data suspend;