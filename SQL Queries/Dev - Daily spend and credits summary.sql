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

WITH DailyAggregates AS (
  SELECT
    usage_start_date,
    SUM(total_cost) AS total_cost,
    SUM(total_credits) AS total_credits,
    (
      SUM(total_discount) + SUM(total_promotion) + SUM(total_sud) + SUM(total_rcud) + SUM(total_fcud_legacy) + SUM(total_fee_utilization_offset_credits) + SUM(total_free_tier) + SUM(total_reseller_margin) + SUM(total_subscription_benefit)
    ) AS add_all_credit_types,
    SUM(total_discount) AS total_discount,
    SUM(total_promotion) AS total_promotion,
    SUM(total_sud) AS total_sud,
    SUM(total_rcud) AS total_rcud,
    SUM(total_fcud_legacy) AS total_fcud_legacy,
    SUM(total_fee_utilization_offset_credits) AS total_fee_utilization_offset_credits,
    SUM(total_free_tier) AS total_free_tier,
    SUM(total_reseller_margin) AS total_reseller_margin,
    SUM(total_subscription_benefit) AS total_subscription_benefit
  FROM
    `<project>.<dataset>.gcp_billing_export_daily_summary`
  WHERE
    usage_start_date > "2025-01-01"
    -- and  service_description != 'Invoice' -- taxes, etc, this matches a gcp console filter
  GROUP BY
    usage_start_date
),
MonthlyAggregates AS (
  SELECT
    *,
    SUM(total_cost) OVER (PARTITION BY DATE_TRUNC(usage_start_date, MONTH)) AS monthly_total_cost,
    SUM(total_credits) OVER (PARTITION BY DATE_TRUNC(usage_start_date, MONTH)) AS monthly_total_credits,
    SUM(add_all_credit_types) OVER (PARTITION BY DATE_TRUNC(usage_start_date, MONTH)) AS monthly_add_all_credit_types,
    SUM(total_discount) OVER (PARTITION BY DATE_TRUNC(usage_start_date, MONTH)) AS monthly_total_discount,
    SUM(total_promotion) OVER (PARTITION BY DATE_TRUNC(usage_start_date, MONTH)) AS monthly_total_promotion,
    SUM(total_sud) OVER (PARTITION BY DATE_TRUNC(usage_start_date, MONTH)) AS monthly_total_sud,
    SUM(total_rcud) OVER (PARTITION BY DATE_TRUNC(usage_start_date, MONTH)) AS monthly_total_rcud,
    SUM(total_fcud_legacy) OVER (PARTITION BY DATE_TRUNC(usage_start_date, MONTH)) AS monthly_total_fcud_legacy,
    SUM(total_fee_utilization_offset_credits) OVER (PARTITION BY DATE_TRUNC(usage_start_date, MONTH)) AS monthly_total_fee_utilization_offset_credits,
    SUM(total_free_tier) OVER (PARTITION BY DATE_TRUNC(usage_start_date, MONTH)) AS monthly_total_free_tier,
    SUM(total_reseller_margin) OVER (PARTITION BY DATE_TRUNC(usage_start_date, MONTH)) AS monthly_total_reseller_margin,
    SUM(total_subscription_benefit) OVER (PARTITION BY DATE_TRUNC(usage_start_date, MONTH)) AS monthly_total_subscription_benefit
  FROM
    DailyAggregates
)
SELECT
  usage_start_date,
  -- Format all numeric columns using the corrected FORMAT specifier
  CONCAT('$ ', FORMAT("%'.2f", total_cost)) AS total_cost,
  CONCAT('$ ', FORMAT("%'.2f", total_cost+total_fcud_legacy)) AS total_net_cost,
  CONCAT('$ ', FORMAT("%'.2f", total_promotion)) AS total_promotion,
  CONCAT('$ ', FORMAT("%'.2f", total_credits)) AS total_credits,
  CONCAT('$ ', FORMAT("%'.2f", add_all_credit_types)) AS add_all_credit_types,
  CONCAT('$ ', FORMAT("%'.2f", total_discount)) AS total_discount,
  CONCAT('$ ', FORMAT("%'.2f", total_sud)) AS total_sud,
  CONCAT('$ ', FORMAT("%'.2f", total_rcud)) AS total_rcud,
  CONCAT('$ ', FORMAT("%'.2f", total_fcud_legacy)) AS total_fcud_legacy,
  CONCAT('$ ', FORMAT("%'.2f", total_fee_utilization_offset_credits)) AS total_fee_utilization_offset_credits,
  CONCAT('$ ', FORMAT("%'.2f", total_free_tier)) AS total_free_tier,
  CONCAT('$ ', FORMAT("%'.2f", total_reseller_margin)) AS total_reseller_margin,
  CONCAT('$ ', FORMAT("%'.2f", total_subscription_benefit)) AS total_subscription_benefit,
  CONCAT('$ ', FORMAT("%'.2f", monthly_total_cost)) AS monthly_total_cost,
  CONCAT('$ ', FORMAT("%'.2f", monthly_total_credits)) AS monthly_total_credits,
  CONCAT('$ ', FORMAT("%'.2f", monthly_add_all_credit_types)) AS monthly_add_all_credit_types,
  CONCAT('$ ', FORMAT("%'.2f", monthly_total_discount)) AS monthly_total_discount,
  CONCAT('$ ', FORMAT("%'.2f", monthly_total_promotion)) AS monthly_total_promotion,
  CONCAT('$ ', FORMAT("%'.2f", monthly_total_sud)) AS monthly_total_sud,
  CONCAT('$ ', FORMAT("%'.2f", monthly_total_rcud)) AS monthly_total_rcud,
  CONCAT('$ ', FORMAT("%'.2f", monthly_total_fcud_legacy)) AS monthly_total_fcud_legacy,
  CONCAT('$ ', FORMAT("%'.2f", monthly_total_fee_utilization_offset_credits)) AS monthly_total_fee_utilization_offset_credits,
  CONCAT('$ ', FORMAT("%'.2f", monthly_total_free_tier)) AS monthly_total_free_tier,
  CONCAT('$ ', FORMAT("%'.2f", monthly_total_reseller_margin)) AS monthly_total_reseller_margin,
  CONCAT('$ ', FORMAT("%'.2f", monthly_total_subscription_benefit)) AS monthly_total_subscription_benefit
FROM
  MonthlyAggregates
ORDER BY
  usage_start_date ASC
LIMIT
  1000
;
