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

### Layered Architecture
<br/>
<img src="assets\Layered-Architecture-Standard-Names.png" width="500"/>

The stage layer ingest the data to an internal stage.
- once ingested, audit columns are added from the **metadata$filename** as _stg_file_name,      **metadata$FILE_LAST_MODIFIED** as _stg_file_load_ts, **metadata$FILE_CONTENT_KEY** as _stg_file_md5, and the **current_timestamp()** as _copy_data_ts is used for a load time capture. 
- Also added fpr audit purposes are the version and count of records for that time period.
- The JSON data is captured in a VARIANT column whihc is extracted later in the clean process.
- This layer is to really add our audit columns and put the JSON data in a VARIANT column. 

A task is created here to automate the ingestion.

### Stage & Clean Layer with All Attributes Before final Transpose
<br/>
<img src="assets\Table-Design+(Stage+++Clean+Layer).png" width="500"/>

Once staged, it is time to clean the daat and use dynamic tables for our transforms.

In this layer, we first **flatten** and **de-duplicate** the data (additional files are laoded that are dups for example) using a window function to capture all duplicate values.
- Snowflakes **f;atten** function is used to create a tabular representation of the **VARIANT** data for a select number of records associated with the above requirements.

### Stage to clean layer DAG
<br/>
<img src="assets/stg-clean-DAG.png" width="500"/>




### Dimensional Model (Consumtion Layer)
<br/>
<img src="assets\Fact+&+Dim+Tables+(Consumption+Layer9.png" width="500"/>