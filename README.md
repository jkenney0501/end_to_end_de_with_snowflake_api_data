# end_to_end_de_with_snowflake_api_data

This project takes weather air qulity data form an API an dingest the JSON files into Snowflake. 
Frm here we target several layers to store, clean and transform the data for consumption while also creating a dimensaionl amodel and one big table example.

Requirements:
- inegst API data.
- add audit columns to stage layer.
- transform JSON data to VARIANT.
- extract select dimension for location and select measures to create avergare AQI for 7 pollutants.
- cerate a consumable dimensianl model.
- create one large table model.
- create aggregated fact table.
- create visualization with streamlit
- integrate API Data source with snowflake using snowpark.


### Steps

1. import json data to stage
2. add ausit columns
3. capactiy plan
4. flatten json/variant data column to prepare for clean layer
5. create task to automate load and transdformation from stage to clean
6. create dynamic table
7. model data dimensianlly
8. model data for one big table


### The Layered Architecture Process Flow 
<br/>
<img class="center-block" src="assets\Layered-Architecture-Standard-Names.png" width="750"/>

The stage layer ingest the data to an internal stage.
- once ingested, audit columns are added from the **metadata$filename** as _stg_file_name,      **metadata$FILE_LAST_MODIFIED** as _stg_file_load_ts, **metadata$FILE_CONTENT_KEY** as _stg_file_md5, and the **current_timestamp()** as _copy_data_ts is used for a load time capture. 
- Also added fpr audit purposes are the version and count of records for that time period.
- The JSON data is captured in a VARIANT column whihc is extracted later in the clean process.
- This layer is to really add our audit columns and put the JSON data in a VARIANT column. 

A task is created here to automate the ingestion. Below is what the table lookks like at the stage layer with audit columns added and the JSON data stored as VARIANT (in column $1).

<img class="center-block" src="assets\stage_with_audit_cols_variant.png" width="750"/>

### Capacity Plan:
- what will happen if we add more data?
    - max variant column size is 16MB compressed per row in Snowflake.
    - file size for the seven mmetrics per hour per station is aorunf 24 * 7 given we have 24 hours in a day which = 168
    - if there are 500 stations then 500 * 168 = 84k. Conver this to MB and we have around 84k / 1024 for about 82GB per day.
    - this is a lot of data BUT thee are sevral points here:
        - each hour represents a row and is well witihn the limts of 16MB.
        - our max intake per day is generally around 82GB for all stations. Cloud storage can handle this easily as it.

**Notable:** *we will reduce this late as the seven metrics will al be part of one row and reduce the sice by a factor of six.*

## Stage & Clean Layer with All Attributes Before final Transpose
<br/>
<img class="center-block" src="assets\Table-Design+(Stage+++Clean+Layer).png" width="750"/>

Once staged, it is time to clean the daat and use dynamic tables for our transforms.

In this layer, we first **flatten** and **de-duplicate** the data (additional files are laoded that are dups for example) using a window function to capture all duplicate values.
- Snowflakes **f;atten** function is used to create a tabular representation of the **VARIANT** data for a select number of records associated with the above requirements.

## Stage to clean layer DAG

<img class="center-block" src="assets/stg-clean-DAG.png" width="750"/>

## Modeling the Data

### [Wide Table Approach]('1-sql-scripts\05-wide-table-consumption.sql)

- the target lag is 30 minutes fo each dynamic table in the DAG. Refresh occurs every 30 minutes and travles downstream (left to right in the DAG)

<img class="center-block" src="assets/wide table dag.png" width="750"/>

### Dimensional Model (Consumtion Layer)

- creates one fact and two dimension tables.

- the fact captures the measurments and the dims capture the context (aka location, etc).

<img class="center-block" src="assets\Fact+&+Dim+Tables+(Consumption+Layer9.png" width="750"/>

### Fact DAG
- the dag below shows the dependencies of the dyamic tables with a 30 minute lag.
- the fact and dims update from the clean and flatten table which updates from the clean whohc updates from the stage.

<img class="center-block" src="assets\FACT_DAG.png" width="750"/>


### Refresh Dynamic Tables with New Data: mimick the an automated process (or use it as with cron).
-- add day 2-5 files (approximately 90 files) manullay to internal stage and then:
- run task manuualy or on cron shcedule and tables will update as data is added to the stage layer via API.
- or tables can also be updated manually with a click of the button below.
- either way will illustrate how the task and dynamic tables work in the DAG. Each node needs refreshed (dims/facts)
<img class="center-block" src="assets\manual_refresh_dynamic_tables.png" width="750"/>

## Createing the Aggregated Fact for User Consumption