/*
# Copyright 2026 Google LLC
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
*/

-- This query converts the schema definition into a partial create table statement for a specified table or view
SELECT
STRING_AGG(column_name || ' ' || data_type, ',\n  ' ORDER BY ordinal_position) schema_def
,string_agg(column_name,',\n' order by ordinal_position) select_def
FROM
`<project>`.`<dataset>`.INFORMATION_SCHEMA.COLUMNS 
WHERE
table_catalog = '<project>' AND -- Ensure correct project if multiple are accessible
table_schema = '<dataset>' AND
table_name = '<table_or_view_name>'  -- Replace with your table or view name

