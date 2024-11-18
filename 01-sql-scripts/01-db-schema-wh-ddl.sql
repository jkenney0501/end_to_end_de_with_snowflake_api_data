-- create the db's, schemas and wh's needed for the threee layers we will use.


-- create development database/schema  if does not exist
create database if not exists dev_db;
create schema if not exists dev_db.stage_sch;
create schema if not exists dev_db.clean_sch;
create schema if not exists dev_db.consumption_sch;
create schema if not exists dev_db.publish_sch;


-- see all your schemas
show schemas in database dev_db;

-- visit the object explorer home page from web-ui.

-- having load_wh warehouse
create warehouse if not exists load_wh
     comment = 'this is load warehosue for loading all the JSON files'
     warehouse_size = 'medium' 
     auto_resume = true 
     auto_suspend = 60  -- shuts down after 1 minute
     enable_query_acceleration = false  -- this is fr large scan using serverless compute
     warehouse_type = 'standard'   -- other option is snowpark-optimized
     min_cluster_count = 1 
     max_cluster_count = 1 
     scaling_policy = 'standard' -- will favor multi clister over credit consumption, other option is economy which favors ccc over mc.
     initially_suspended = true; -- starts in suspend mode


-- all the ETL workload will be manage by it.
create warehouse if not exists transform_wh
     comment = 'this is ETL warehosue for all loading activity' 
     warehouse_size = 'x-small' 
     auto_resume = true 
     auto_suspend = 60
     enable_query_acceleration = false 
     warehouse_type = 'standard' 
     min_cluster_count = 1 
     max_cluster_count = 1 
     scaling_policy = 'standard'
     initially_suspended = true;


-- specific virtual warehouse with differt resume time (for streamlit, it should be longer)
 create warehouse if not exists streamlit_wh
     comment = 'this is streamlit virtual warehouse' 
     warehouse_size = 'x-small' 
     auto_resume = true
     auto_suspend = 300 
     enable_query_acceleration = false 
     warehouse_type = 'standard' 
     min_cluster_count = 1 
     max_cluster_count = 1 
     scaling_policy = 'standard'
     initially_suspended = true;


-- dhoc warehouse, most dev will use this
create warehouse if not exists adhoc_wh
     comment = 'this is adhoc warehosue for all adhoc & development activities' 
     warehouse_size = 'x-small' 
     auto_resume = true 
     auto_suspend = 60 
     enable_query_acceleration = false 
     warehouse_type = 'standard' 
     min_cluster_count = 1 
     max_cluster_count = 1 
     scaling_policy = 'standard'
     initially_suspended = true;



-- see your wh's
show warehouses;

-- also, visit the warehouse home page from webui.
