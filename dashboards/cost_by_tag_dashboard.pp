dashboard "tag_cost_detail_dashboard" {
  title = "Cost by Tag Dashboard"

  tags = {
    type    = "Dashboard"
    service = "AWS/CostExplorer"
  }

  input "account" {
    title       = "Select account:"
    description = "Select an AWS account to filter the dashboard."
    type        = "multiselect"
    query       = query.tag_details_aws_account_input
    width       = 2
  }

  container {
    # Summary Metrics
    card {
      width = 2
      query = query.tag_total_cost
      args  = {
        "line_item_usage_account_id" = self.input.account.value
      }
    }

    card {
      width = 2
      query = query.tag_currency
      args  = {
        "line_item_usage_account_id" = self.input.account.value
      }
    }
  }

  container {
    # Cost Trend and Key/Value Breakdown
    chart {
      title = "Monthly Cost by Tag"
      type  = "bar"
      width = 6
      query = query.monthly_cost_by_tag
      args  = {
        "line_item_usage_account_id" = self.input.account.value
      }

      axes {
        y {
          title {
            value = "Month"
          }
        }
        x {
          title {
            value = "Cost ($)"
          }
          min = 0
        }
      }

      legend {
        display  = "none"
        position = "bottom"
      }

      series "Total Cost" {
        title = "Tag Costs"
      }
    }

    chart {
      title = "Top 10 Tags by Cost"
      type  = "pie"
      width = 6
      query = query.top_10_tags_by_cost
      args  = {
        "line_item_usage_account_id" = self.input.account.value
      }

     
    }
  }

  container {
    # Detailed Table
    table {
      title = "Tagged Resource Cost Breakdown"
      width = 12
      query = query.tagged_resource_cost_breakdown
      args  = {
        "line_item_usage_account_id" = self.input.account.value
      }
    }
  }

  container {
    # Untagged Resources Table
    table {
      title = "Untagged Resources Cost Breakdown"
      width = 12
      query = query.untagged_resource_cost_breakdown
      args  = {
        "line_item_usage_account_id" = self.input.account.value
      }
    }
  }
}

# Query Definitions

query "tag_total_cost" {
  title       = "Total Cost"
  description = "Total unblended cost for the selected AWS account."
  sql = <<-EOQ
    select 
      round(sum(line_item_unblended_cost), 2) as "Total Cost"
    from 
      aws_cost_and_usage_report
    where 
      ('all' in ($1) or line_item_usage_account_id in $1);
  EOQ

  param "line_item_usage_account_id" {}
}

query "tag_currency" {
  title       = "Currency"
  description = "Currency used for cost calculations in the selected AWS account."
  sql = <<-EOQ
    select 
      distinct line_item_currency_code as "Currency"
    from 
      aws_cost_and_usage_report
    where 
      ('all' in ($1) or line_item_usage_account_id in $1)
    limit 1;
  EOQ

  param "line_item_usage_account_id" {}
}

query "monthly_cost_by_tag" {
  title       = "Monthly Cost per Tag"
  description = "Aggregated cost per month for each tag in the selected AWS account."
  sql = <<-EOQ
    with json_entries as (
    select 
      unnest(regexp_split_to_array(trim(both '{}' from resource_tags), ',')) as entry,
      line_item_usage_start_date,
      line_item_usage_account_id,
      line_item_unblended_cost
    from 
      aws_cost_and_usage_report
    ),
    parsed_entries as (
      select 
        trim(split_part(entry, ':', 1), ' "') as tag_key,
        trim(split_part(entry, ':', 2), ' "') as tag_value,
        line_item_usage_start_date,
        line_item_usage_account_id,
        line_item_unblended_cost
      from 
        json_entries
      where
        trim(split_part(entry, ':', 2), ' "') != ''
    ),
    formatted_entries as (
      select
        tag_key,
        case 
          when tag_value like '%@%' then -- Email address
            split_part(tag_value, '@', 1)
          when tag_value like 'arn:aws:%' then -- ARN
            concat(
              split_part(tag_value, ':', 3), '/',
              split_part(split_part(tag_value, '/', -1), '-', 1)
            )
          when length(tag_value) > 20 then -- Long values
            substring(tag_value, 1, 20) || '...'
          else tag_value
        end as formatted_value,
        line_item_usage_start_date,
        line_item_unblended_cost,
        tag_value as original_value
      from 
        parsed_entries
      where 
        ('all' in ($1) or line_item_usage_account_id in $1)
    ),
    tag_costs as (
      select 
        date_trunc('month', line_item_usage_start_date) as month,
        concat('{ ', tag_key, ': ', original_value, ' }') as tag,
        sum(line_item_unblended_cost) as cost
      from 
        formatted_entries
      group by 
        date_trunc('month', line_item_usage_start_date),
        tag_key,
        original_value
    )
    select 
      strftime(month, '%b %Y') as "Month",
      tag as "Series",
      round(cost, 2) as "Total Cost"
    from 
      tag_costs
    order by 
      month, cost desc;
  EOQ

  param "line_item_usage_account_id" {}
}

query "top_10_tags_by_cost" {
  title       = "Top 10 Tags by Cost"
  description = "List of top 10 tags with the highest cost in the selected AWS account."
  sql = <<-EOQ
    with json_entries as (
      select 
        unnest(regexp_split_to_array(trim(both '{}' from resource_tags), ',')) as entry,
        line_item_usage_account_id,
        line_item_unblended_cost
      from aws_cost_and_usage_report
    ),
    parsed_entries as (
      select 
        trim(split_part(entry, ':', 1), ' "') as tag_key,
        trim(split_part(entry, ':', 2), ' "') as tag_value,
        line_item_usage_account_id,
        line_item_unblended_cost
      from 
        json_entries
      where 
        trim(split_part(entry, ':', 2), ' "') != ''
    ),
    formatted_entries as (
      select
        tag_key,
        case 
          when tag_value like '%@%' then -- Email address
            split_part(tag_value, '@', 1)
          when tag_value like 'arn:aws:%' then -- ARN
            concat(
              split_part(tag_value, ':', 3), '/',
              split_part(split_part(tag_value, '/', -1), '-', 1)
            )
          when length(tag_value) > 20 then -- Long values
            substring(tag_value, 1, 20) || '...'
          else tag_value
        end as formatted_value,
        line_item_unblended_cost,
        tag_value as original_value
      from 
        parsed_entries
      where 
        ('all' in ($1) or line_item_usage_account_id in $1)
    ),
    tag_costs as (
      select 
        tag_key,
        formatted_value,
        original_value,
        sum(line_item_unblended_cost) as cost
      from 
        formatted_entries
      group by 
        tag_key,
        formatted_value,
        original_value
    )
    select 
      concat('{ ', tag_key, ': ', formatted_value, ' }') as "Tag",
      round(cost, 2) as "Total Cost"
    from 
      tag_costs
    order by 
      cost desc
    limit 10;
  EOQ

  param "line_item_usage_account_id" {}
}

query "tagged_resource_cost_breakdown" {
  title       = "Tagged Resource Cost Breakdown"
  description = "Detailed cost breakdown of resources with tags."
  sql = <<-EOQ
    WITH json_entries AS (
      SELECT 
        unnest(regexp_split_to_array(trim(both '{}' from resource_tags), ',')) as entry,
        line_item_usage_account_id,
        line_item_unblended_cost,
        product_region_code,
        line_item_resource_id,
        line_item_product_code
      FROM aws_cost_and_usage_report
    ),
    parsed_entries AS (
      SELECT 
        trim(split_part(entry, ':', 1), ' "') as tag_key,
        trim(split_part(entry, ':', 2), ' "') as tag_value,
        line_item_usage_account_id,
        line_item_unblended_cost,
        product_region_code,
        line_item_resource_id,
        line_item_product_code
      FROM json_entries
      WHERE trim(split_part(entry, ':', 2), ' "') != ''
    ),
    formatted_entries AS (
      SELECT
        tag_key,
        CASE 
          WHEN tag_value LIKE '%@%' THEN -- Email address
            split_part(tag_value, '@', 1)
          WHEN tag_value LIKE 'arn:aws:%' THEN -- ARN
            concat(
              split_part(tag_value, ':', 3), '/',
              split_part(split_part(tag_value, '/', -1), '-', 1)
            )
          WHEN length(tag_value) > 20 THEN -- Long values
            substring(tag_value, 1, 20) || '...'
          ELSE tag_value
        END as formatted_value,
        line_item_unblended_cost,
        line_item_resource_id,
        line_item_product_code,
        product_region_code,
        tag_value as original_value
      FROM parsed_entries
      WHERE
        ('all' in ($1) or line_item_usage_account_id in $1)
    )
    SELECT 
      concat('{ ',tag_key, ': ', original_value, ' }') as "Tag",
      line_item_resource_id as "Resource ID",
      line_item_product_code as "Service",
      coalesce(product_region_code, 'global') as "Region",
      round(sum(line_item_unblended_cost), 2) as "Total Cost"
    FROM formatted_entries
    GROUP BY 
      tag_key, 
      original_value,
      original_value,
      line_item_resource_id,
      line_item_product_code,
      product_region_code
    ORDER BY sum(line_item_unblended_cost) DESC;
  EOQ

  param "line_item_usage_account_id" {}
}

query "untagged_resource_cost_breakdown" {
  title       = "Untagged Resources Cost Breakdown"
  description = "Detailed cost breakdown of resources without any tags."
  sql = <<-EOQ
    SELECT 
      line_item_resource_id as "Resource ID",
      line_item_product_code as "Service",
      coalesce(product_region_code, 'global') as "Region",
      line_item_usage_account_id as "Account",
      round(sum(line_item_unblended_cost), 2) as "Total Cost"
    FROM aws_cost_and_usage_report
    WHERE 
      ('all' in ($1) or line_item_usage_account_id in $1)
      AND (resource_tags is null OR resource_tags = '{}')
    GROUP BY line_item_resource_id, line_item_product_code, product_region_code, line_item_usage_account_id
    ORDER BY sum(line_item_unblended_cost) DESC;
  EOQ

  param "line_item_usage_account_id" {}
}

query "tag_details_aws_account_input" {
  sql = <<-EOQ
    select
      'All' as label,
      'all' as value
    union all
    select distinct
      line_item_usage_account_id as value,
      line_item_usage_account_id as label
    from
      aws_cost_and_usage_report;
  EOQ
}
