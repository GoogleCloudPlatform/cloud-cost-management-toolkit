# GCP Billing Toolkit Schema Design Document

This project is a data pipeline that improves the analytical usability of the [GCP Billing Export](https://docs.cloud.google.com/billing/docs/how-to/export-data-bigquery). The Billing Export is a useful tool since it contains accurate cost information for all services across GCP. However, it is often too large to be easily analyzed, and has certain design nuances that make it particularly difficult to approach. This document describes how the GCP Billing Toolkit’s Dataform powered data engineering pipeline improves this data that can power GCP cost analysis.

## Background on GCP Billing Export Partitions

The raw GCP Billing Export table sourced by the pipeline is set up for optimal usage by downstream ETL processes and for resilience to shifting shapes of the data. Specifically, it is partitioned by data ingestion time ( \_PARTITIONDATE) and uses arrays that require analytically complex unnesting to utilize. This is in contrast to optimization for analysis, which would prioritize query performance despite introducing complexities to the data maintenance process. This is actually a sensible design choice, but only if there is a layer added which takes the raw (optimized for loading) data table and transforms it into one or more tables optimized for analysis.

Customers with small data volume due to lower GCP activity can usually ignore these issues. However, the scale of some GCP deployments is high enough that querying directly against the raw GCP Billing Export table can result in high costs and slow performance. For this reason, a data pipeline was built to solve three key issues:

1) Partition tables by “usage date” (e.g. usage\_start\_time truncated to DAY) rather than the day of arrival (*PARTITIONDAY,* probably derived from export\_time). Partitioning on a date not used in analysis leads to higher scan costs and up to 10x increase in query slowness.  
2) Summarize at the daily granularity, as this is adequate for most analysis and anomaly detection.  
3) Pivot the credits array so that queries involving them do not require a subquery costly to performance. Also pivot the other array columns for the same reason, but credits are the most commonly used.

At the close of each UTC day we process the completed day’s \_PARTITIONDATE in the raw GCP Billing Export, and update a separate GCP billing table partitioned by usage\_start\_date (DATE truncate of usage\_start\_time) and generate a PK to allow for efficient analytic queries.

The goals of this pipeline include:

* Perform a daily load at the close of each UTC day  
* Orchestrate entirely with Dataform-native features  
  * NOTE: API endpoints are available in Dataform for orchestration with other services like Composer/Airflow or Cloud Workflows if desired.  
* Only scan partitions that are needed for incremental updates, on both source and target tables (enforce partition pruning at all times)  
* Build and maintain a daily summary table appropriate for analytics and reporting.  
  * In order to achieve this goal, a repartitioned (but otherwise raw and therefore not intended for analytics) table is built in between the raw export and the daily summary.  
* Use of a view layer to provide a durable reporting schema.  
  * It is best practice to point reports at views (vw\_gcp\_billing\_export\_daily\_summary), not the base tables (gcp\_billing\_export\_daily\_summary). This allows flexibility to modify certain definitions, such as total\_net\_cost, without disturbing the reporting layer or the actual table

## Additional Details on GCP Billing Export Partitions

The most impactful improvement from the pipeline is repartitioning the billing data to usage date. This simple improvement has two major advantages. First, it allows for intuitive partition handling at query time. With the native partitioning strategy (on ingestion date), queries must take into account all partitions since the earliest usage date in the query, to account for late-arriving data. Typically 2-3 days late is sufficient, but even later modifications can arrive. This results in more data overall being scanned, and an unintuitive filter required to prevent additional cost (in addition to any usage date filtering already in place). 

Second, the operations required to do aggregations across multiple partitions results in some of the least efficient operations in BigQuery. For example, period over period calculations, especially ones that include unnesting of labels, require major portions of the calculation to operate outside of a single partition, significantly reducing performance. For example, 10x slower results have been observed when using a table partitioned on a date other than the group by date, compared to simply not using partitions at all.

## Additional Details on Handling Arrays in the GCP Billing Export

Arrays offer a flexible way to store data, but that flexibility comes at the cost of query complexity. The pipeline created in this solution improves this in three ways.

### Grouping by arrays

In the case of the GCP Billing Export, the crucial goal of summarizing it down to a daily grain without losing information cannot be easily accomplished with these array fields, since array type columns cannot be a part of a SQL group by nor aggregation. Therefore, the first step in handling these arrays is to convert them into a string which can be grouped by, like this:

```sql
ARRAY_TO_STRING(
 ARRAY(
  SELECT CONCAT(
   coalesce(key,'No Label Key'),
   ':::',
   coalesce(value,'No Label Value')
  ) FROM UNNEST(labels)
 ), ', '
) AS all_labels
```

This formulation retains all the values for the two useful array elements (key and value), and also retains the ability to unnest that array. However, since it is now stored as a string, it can also be a part of the group by clause, thus allowing the query to perform the desired daily summarization.

### Pivoting and fanning out arrays without known possible values

In the Billing Export, 4 of the 6 array fields  (labels, project.labels, system\_labels, tags) contain records with “key” element values that cannot be known for certain ahead of time. This is because for every label key that has been applied to that billing export line item an additional record is added to the array. Combining the labels.key element value with the labels.value element value on each billing\_export.labels array record provides the information needed to do analysis with labels (same with project labels, system labels, and tags). The first step to do this is completed in the group by stage described above, where the key value pairs are stored in a string that mimics an array. From there, the arrays can be handled during analysis in either a pivoted or intentionally fanned out way.

Pivoting the array keys into one column per key of interest is best done ahead of time and incrementally in the data pipeline along with the daily summary table. This is partially because it requires a relatively slow query, but also because it is a complicated query. Check out this example from the dataform step which builds the labels helper table (definitions/output/03\_build\_labels.sqlx):

```sql
(SELECT SPLIT(trim(label_array),':::')[1]
FROM UNNEST(SPLIT(billing_export.all_labels,',')) as label_array
WHERE SPLIT(trim(label_array),':::')[0]='application-name'
) AS label_application_name
```

These are known as pivoted array elements; instead of each key being a new record (i.e. row) in the array, they are a new column in a table. This allows for multiple label keys to be grouped by simultaneously, and therefore costs can be further refined even deeper than just one label key. It is even possible to add new columns (best done in a view layer built on the helper table) which use information from multiple label keys in their definition. A potential room for improvement would be to utilize BigQuery’s [pivot operator](https://docs.cloud.google.com/bigquery/docs/reference/standard-sql/query-syntax#pivot_operator), which might offer improved performance.

These helper tables are designed to be joined to the daily summary table using the primary key field, “pk.” That field is the same in each label helper table as they are in the daily summary, resulting in a straightforward one to one join relationship.

### Fanning out billing table for attribution of line item costs

In addition to the pivoted helper tables, it is also possible to query the string representation of the array such that the array is unnested and fans out the data. Fanning out the billing table using labels might seem unsensible, as it duplicates cost values. However, consider the analysis where the cost associated with each label key-value pair is being compared. There are many cases where the same billing line item is associated with multiple label key-value pairs, and that line item cost needs to be attributed to each of them to properly do this analysis. This calls for an intentional fanout of the billing table, duplicating records according to how many label key-value pairs with which it is associated. This is demonstrated in the sample SQL available in the repository at **SQL Queries/Dev \- Find labels in use.sql**.

```sql
--see "Dev - Find labels in use.sql" in repo for up-to-date logic
SELECT
 SPLIT(trim(label_array),':::')[0] as label_key,
 sum(total_net_cost) as total_net_cost
FROM `vw_gcp_billing_export_daily_summary` as gcp_billing_export 
LEFT JOIN UNNEST(SPLIT(gcp_billing_export.all_labels,',')) as label_array 
WHERE usage_start_date>'2025-10-01'
GROUP BY 1
ORDER BY 2 desc
LIMIT 1000
```

A more realistic analysis, looking for which key-value label pair is contributing most to cost, might look something like this:

```sql
SELECT
 SPLIT(trim(label_array),':::')[0] as label_key,
 SPLIT(trim(label_array),':::')[1] as label_value,
 sum(total_net_cost) as total_net_cost --accurate despite fanout because grouping by label_array
FROM `vw_gcp_billing_export_daily_summary` as gcp_billing_export 
LEFT JOIN UNNEST(SPLIT(gcp_billing_export.all_labels,',')) as label_array --creates fanout of cost, one row per label key-value pair in each cost line item
WHERE usage_start_date>'2025-10-01'
GROUP BY 1,2
ORDER BY 3 desc
LIMIT 1000

```

### Pivoting the credits array, which has known possible values

The Credits array is unique among the 6 arrays in that the full range of possible values of the credits.type field are limited to a known set of 9 values (see aggregations in the daily summary sql in dataform file definitions/output/02\_build\_daily\_aggregate.sqlx for the list). This makes it possible to extract all information in the credits.amount field using a SQL pattern known as scalar subqueries. Here is an example from the select clause of the daily summary table:

```sql
--this is done 9 times, once for each possible value of credits.type
COALESCE(SUM(
 SELECT SUM(amount)
 FROM UNNEST(billing_export.credits)
 WHERE type = 'PROMOTION'
),0) as total_promotion
```

A [scalar subquery](https://docs.cloud.google.com/bigquery/docs/reference/standard-sql/subqueries#scalar_subquery_concepts) can be used right inside the select clause of another query so long as it only returns a single column and row. It is then subject to the same group by clause as the main query. This scalar subquery is particularly useful since it allows for the unnesting of the credits array without affecting the main query with that unnesting. Unnesting causes the one-to-many [fanout problem](https://discuss.google.dev/t/the-problem-of-sql-fanouts/119220), which can usually only be solved with a subquery. Note that the array\_to\_string query for labels also contains a scalar subquery.

Technically, the project.ancestors array also has a known set, since the number of org and folder hierarchies are limited when only looking at one customer. However, since this solution was designed to easily be maintained across any number of customers (or organizations at a single customer), it was handled like the label arrays. In addition, all the information in the project.ancestors array is also contained in the project.ancestry\_numbers string, so in a future iteration of this solution the project.ancestors array will likely be removed from the daily summary altogether. To pivot the ancestors array in the same way that labels are handled, then that would indeed require handling them like the labels arrays.
