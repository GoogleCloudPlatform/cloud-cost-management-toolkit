# GCP Billing Toolkit Dataform Pipeline Design Document

# Introduction to Dataform 

The service used for this data pipeline is [Dataform](https://docs.cloud.google.com/dataform/docs/quickstart-create-workflow), which is part of the BigQuery family of services and allows for development of data pipelines using SQL-like programming and version-control supported “gitflow” based development, with scheduling built in or optionally available via API triggers to other orchestration services like Composer and Cloud Workflows or even non-GCP tools.

A Dataform pipeline consists of a series of SQLX files, which contain SQL wrapped in a YAML-like language for defining ETL workflows, with the tables in FROM and JOIN clauses replaced by references to other SQLX files. Each SQLX file begins with a configuration block and can also contain optional pre and post operation blocks that are executed before and after the main query.

```sql
-- Configuration block at the top of every SQLX file
config {
  type: "table",  --or "view", or "incremental"
  name: "name_of_table_to_create",  -- if not specified, defaults to filename 
  dependencies: ["00_init_pipeline"], --dependency explicitly added
  tags: ["updateBaseTables"],  --developer-assigned label(s)
  bigquery: {
    partitionBy: "usage_start_date",
    partitionExpirationDays: -1,    -- days to keep, -1 means keep forever
    requirePartitionFilter: true  -- don't allow unfiltered queries
  },
  description: "Table description will be used as table metadata in BigQuery"
}

pre_operations {
   -- Run SQL or PLSQL before main query is executed
}

-- Main query
SELECT
  source_data.* ,
  DATE(source_data.usage_start_time) AS usage_start_date
FROM -- SQLX references other files in the project to create a lineage graph
  ${ref("name_of_source_table_in_Dataform_project")} AS source_data

post_operations {
   -- Run SQL or PLSQL after main query is executed
}
```

As shown in above example code in the FROM clause, the SQLX file can reference other SQLX files in the project, referencing them by filename. These referenced source tables are tracked as dependencies, as well as any dependencies explicitly called out in the name attribute in the config block. The dependencies which are tracked in Dataform’s “Compiled Graph” tab available in the Dataform console interface.  
![][image1]

Dataform operators like $ref() are translated into executable GoogleSQL code that runs on BigQuery via a compile step. This step can be previewed during development in the “Compiled queries” panel

# Orchestration of the GCP Billing Dataform Pipeline

Dataform executions are scheduled in the *Releases & scheduling* tab by configuring one or more *Release configurations* that represent the compiled outputs linked to a selected branch in the repository. In the example below it is showing a ***production*** Release configuration that is built daily at 1:00 AM UTC from the main branch, along with an additional on-demand only Release configuration associated with a development branch. The Workflow is scheduled to run a few minutes later at 1:05 AM UTC, timed to capture a full partition from the GCP Billing Export source table soon after it is available.

![][image2]

The Release configuration is also where the Compilation overrides for the release can be set, which override the default values of the variables available in the project’s workflow\_settings.yaml configuration file. The overrides can (optionally) be used to maintain multiple dev environments by use of another GCP project per-compilation, adding a suffix to the default dataset, or a prefix to tables and views generated. For reporting from a single billing account, the use of compilation overrides is not required.

In order to be scheduled, the GCP Billing pipeline must have at least one production Release configuration defined with the following suggested options:

* Release ID: **production**  
* Git commitish: **main**  
* Schedule frequency: **Repeat Daily 12:01 AM UTC**  
* No compilation overrides used (default variables)

Once the production Release configuration is available, the Dataform pipeline can be scheduled by creating a *Workflow configuration*, which is responsible for executing the jobs in BigQuery.

For the GCP Billing pipeline, we have set the following options to create a daily incremental batch run based on the production Release configuration referenced earlier:

* Configuration ID: **runDailyUpdate**  
* Release configuration: **production**  
* Schedule frequency: **Repeat Daily at 12:15 AM UTC**  
* Selection of tags: **createViews, init, updateAggregates, updateBaseTables**  
* Execution options: “**Execute as interactive job**” checked, all other options UNCHECKED

![][image3]

# Troubleshooting Dataform Executions

For scheduled runs, start with the Workflow configurations, at the bottom of the Releases & Scheduling tab. This will display the last 5 executions, click the area with the green/red indications to access the Workflow Execution logs.  
![][image4]  
Note that the execution logs will show a mix of scheduled Workflow executions (runDailyUpdate) and other workspace activity from developers. Click any job to examine the details, or click the Gemini icon next to any failed executions for an automated root-cause analysis.  
![][image5]  
The details of the execution will include the output of every step run in BigQuery, with associated JobID and full SQL generated from Dataform available in “View Details”  
![][image6]

Example “View details” shown below. Note that just like the Dataform Compiled Results panel, the contents can be easily cut and pasted for analysis in BigQuery Studio.

Unlike the Compiled Results panel, this SQL includes the actual logic run on BigQuery, complete with the PLSQL automatically added by Dataform to handle pre-checks, incremental loads, and object refreshes. When troubleshooting execution issues, this version should be used rather than Compiled Results for best results.  
![][image7]

Another important resource for troubleshooting is the ETL log table, billing\_process. Use the billing\_process table to determine if the job ran on schedule (after the end of UTC midnight) and if so, if any errors are logged in the process\_msg column. 

![][image8]

The records\_added column should also be populated with a non-zero number, since multiple runs per day will reload the current source partition (current UTC day) and the process\_start\_time should correspond to the first hour of the day UTC time. 

Sample health check queries shown below.

```sql
--analyze last few days of daily summary table for outliers
--
select usage_start_date, -- project_name,
 count(*) , sum(total_cost) as total_cost, sum(total_cost+total_credits) as total_net_cost
FROM `<project>.<dataset>.gcp_billing_export_daily_summary` 
where usage_start_date > '2025-10-15'  --adjust as needed
-- NOTE! This style of relative date filter will NOT prune partitions! 
--and usage_start_date < DATE_SUB(CURRENT_DATE(), INTERVAL 1 DAY) 
group by all
order by 1 desc

--analyze partitions in repartitioned table
--
SELECT PARTITIONDATE, count(*) FROM `<project>.<dataset>.usage_partitioned_billing_export` 
-- NOTE! Make sure to filter on the partitioned column (PARTITIONDATE)
WHERE usage_start_date >= "2025-10-15" and PARTITIONDATE >= "2025-10-15"
group by all
order by 1 desc
```
