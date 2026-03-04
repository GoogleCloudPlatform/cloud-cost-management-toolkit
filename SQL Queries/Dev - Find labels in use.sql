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

SELECT
    SPLIT(trim(label_array),':::')[0],count(*) as count_since_oct_1
 FROM `<project>.<dataset>.gcp_billing_export_daily_summary` as gcp_detailed_billing_export 
 left join UNNEST(SPLIT(gcp_detailed_billing_export.all_labels,',')) as label_array 
 where usage_start_date>'2025-10-01' --arbitrary recent date to limit data scanned
 group by 1
 order by 2 desc
 LIMIT 1000
