dashboard "tag_key_cost_detail_dashboard" {
  title         = "Cost by Tag Key Dashboard"
  documentation = file("./dashboards/docs/tag_key_cost_detail_dashboard.md")

  tags = {
    type    = "Dashboard"
    service = "AWS/Billing"
  }

  input "tag_key_account" {
    title       = "Select accounts:"
    description = "Select an AWS account to filter the dashboard."
    type        = "multiselect"
    query       = query.tag_key_aws_account_input
    width       = 2
  }

  input "tag_key" {
    title       = "Select a tag key:"
    description = "Select tag keys to analyze costs by tag values."
    type        = "select"
    query       = query.tag_keys_input
    width       = 2
    args = {
      "line_item_usage_account_id" = self.input.tag_key_account.value
    }
  }

  container {
    # Summary Metrics
    card {
      width = 2
      query = query.tag_key_total_cost
      args = {
        "line_item_usage_account_id" = self.input.tag_key_account.value
        "tag_key"                    = self.input.tag_key.value
      }
    }

    card {
      width = 2
      query = query.tag_key_currency
      args = {
        "line_item_usage_account_id" = self.input.tag_key_account.value
        "tag_key"                    = self.input.tag_key.value
      }
    }
  }

  container {
    # Cost Trend and Key/Value Breakdown
    chart {
      title = "Monthly Cost by Tag Value"
      type  = "column"
      width = 6
      query = query.monthly_cost_by_tag_value
      args = {
        "line_item_usage_account_id" = self.input.tag_key_account.value
        "tag_key"                    = self.input.tag_key.value
      }
      legend {
        display = "none"
      }
    }

    chart {
      title = "Top 10 Tag Values by Cost"
      type  = "table"
      width = 6
      query = query.top_10_tag_values_by_cost
      args = {
        "line_item_usage_account_id" = self.input.tag_key_account.value,
        "tag_key"                    = self.input.tag_key.value
      }
    }
  }

  container {
    # Detailed Tables
    table {
      title = "Cost by Tag Value and Account"
      width = 12
      query = query.tag_value_cost_breakdown
      args = {
        "line_item_usage_account_id" = self.input.tag_key_account.value
        "tag_key"                    = self.input.tag_key.value
      }
    }
  }
}

# Query Definitions

query "tag_key_total_cost" {
  title       = "Total Cost"
  description = "Total unblended cost for the selected AWS account."
  sql         = <<-EOQ
    with parsed_entries as (
      -- extract distinct tag keys and their values from the json resource_tags column
      select distinct 
        t.tag_key,
        json_extract(resource_tags, '$.' || t.tag_key) as tag_value,
        line_item_usage_start_date,
        line_item_usage_account_id,
        line_item_unblended_cost
      from aws_cost_and_usage_report,
      lateral unnest(json_keys(resource_tags)) as t(tag_key) -- correct unnest usage
      where 
        resource_tags is not null
        and ('all' in ($1) or line_item_usage_account_id in $1)
        and ('all' in ($2) or t.tag_key in $2)
        and json_extract(resource_tags, '$.' || t.tag_key) <> '""'
    )
    select 
        round(sum(line_item_unblended_cost), 2) as "total cost"
    from parsed_entries;
  EOQ

  param "line_item_usage_account_id" {}
  param "tag_key" {}
}

query "tag_key_currency" {
  title       = "Currency"
  description = "Currency used for cost calculations in the selected AWS account."
  sql         = <<-EOQ
    with parsed_entries as (
      -- extract distinct tag keys and their values from the json resource_tags column
      select distinct 
        t.tag_key,
        json_extract(resource_tags, '$.' || t.tag_key) as tag_value,
        line_item_currency_code
      from aws_cost_and_usage_report,
      unnest(json_keys(resource_tags)) as t(tag_key)
      where resource_tags is not null
        and ('all' in ($1) or line_item_usage_account_id in $1)
        and t.tag_key in $2
    )
    select 
        distinct line_item_currency_code as "currency"
    from parsed_entries
    limit 1;
  EOQ

  param "line_item_usage_account_id" {}
  param "tag_key" {}
}

query "monthly_cost_by_tag_value" {
  title       = "Monthly Cost by Tag Value"
  description = "Aggregated cost per month for each value of the selected tag keys."
  sql         = <<-EOQ
    with parsed_entries as (
      -- extract distinct tag keys and their values from the json resource_tags column
      select distinct 
        unnest(json_keys(resource_tags)) as tag_key,
        json_extract(resource_tags, '$.' || unnest(json_keys(resource_tags))) as tag_value,
        line_item_usage_start_date,
        line_item_usage_account_id,
        line_item_unblended_cost
      from 
        aws_cost_and_usage_report
      where 
        resource_tags is not null
    ),
    filtered_entries as (
        -- apply filtering based on account and tag key
        select
          tag_key,
          tag_value,
          line_item_usage_start_date,
          line_item_unblended_cost
        from 
          parsed_entries
        where 
          ('all' in ($1) or line_item_usage_account_id in $1)
          and tag_key in $2
          and tag_value <> '""'
    ),
    tag_costs as (
        -- aggregate cost by month and tag_value
        select 
          date_trunc('month', line_item_usage_start_date) as month,
          tag_value,
          sum(line_item_unblended_cost) as cost
        from 
          filtered_entries
        group by 
          date_trunc('month', line_item_usage_start_date),
          tag_value
    )
    select 
      strftime(month, '%b %Y') as "month",
      replace(tag_value, '"', '') as "series",
      round(cost, 2) as "total cost"
    from 
      tag_costs
    order by 
      month,
      cost desc;
  EOQ

  param "line_item_usage_account_id" {}
  param "tag_key" {}
}

query "top_10_tag_values_by_cost" {
  title       = "Top 10 Tag Values by Cost"
  description = "List of top 10 values for the selected tag keys with the highest cost."
  sql         = <<-EOQ
    with parsed_entries as (
      select 
        distinct unnest(json_keys(resource_tags)) as tag_key,
        json_extract(resource_tags, '$.' || unnest(json_keys(resource_tags))) as tag_value,
        line_item_usage_account_id,
        line_item_unblended_cost
      from 
        aws_cost_and_usage_report
      where
        resource_tags is not null
    ),
    filtered_entries as (
      select
        tag_key,
        tag_value,
        line_item_unblended_cost
      from 
        parsed_entries
      where 
        ('all' in ($1) or line_item_usage_account_id in $1)
        and tag_key in $2
        and tag_value <> '""'
    ),
    tag_costs as (
      select 
        tag_value as tag_with_value,
        sum(line_item_unblended_cost) as cost
      from 
        filtered_entries
      group by 
        tag_key,
        tag_value
    )
    select 
      replace(tag_with_value, '"', '') as "Tag Value",
      --format('{:.2f}', round(cost, 2)) as "Total Cost"
      round(cost, 2) as "Total Cost"
    from 
      tag_costs
    order by cost desc
    limit 10;
  EOQ

  param "line_item_usage_account_id" {}
  param "tag_key" {}
}

query "tag_value_cost_breakdown" {
  title       = "Cost by Tag Value and Account"
  description = "Detailed cost breakdown by tag value and account for the selected tag keys."
  sql         = <<-EOQ
    with parsed_entries as (
      select 
        distinct unnest(json_keys(resource_tags)) as tag_key,
        json_extract(resource_tags, '$.' || unnest(json_keys(resource_tags))) as tag_value,
        line_item_usage_account_id,
        line_item_unblended_cost,
        product_region_code
      from 
        aws_cost_and_usage_report
      where
        resource_tags is not null
    ),
    filtered_entries as (
      select
        tag_key,
        tag_value,
        line_item_usage_account_id,
        line_item_unblended_cost,
        product_region_code
      from 
        parsed_entries
      where 
        ('all' in ($1) or line_item_usage_account_id in $1)
        and tag_key in $2
        and tag_value <> '""'
    )
    select 
      replace(tag_value, '"', '') as "Tag Value",
      line_item_usage_account_id as "Account ID",
      coalesce(product_region_code, 'global') as "Region",
      --format('{:.2f}',round(sum(line_item_unblended_cost), 2)) as "Total Cost"
      round(sum(line_item_unblended_cost), 2) as "Total Cost"
    from 
      filtered_entries
    group by 
      tag_key,
      tag_value,
      line_item_usage_account_id,
      product_region_code
    order by 
      "Total Cost" desc;
  EOQ

  param "line_item_usage_account_id" {}
  param "tag_key" {}
}

query "tag_key_aws_account_input" {
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

query "tag_keys_input" {
  title       = "Tag Keys Input"
  description = "List of available tag keys in AWS cost and usage reports."
  sql         = <<-EOQ
    with flattened_tags as (
      select 
        unnest(json_keys(resource_tags)) as tag_key,
        json_extract(resource_tags, '$.' || unnest(json_keys(resource_tags))) as tag_value
      from 
        aws_cost_and_usage_report
      where 
        ('all' in ($1) or line_item_usage_account_id in $1)
        and resource_tags is not null
        and array_length(json_keys(resource_tags)) > 0
    )
    select distinct
      tag_key as label, 
      tag_key as value
    from 
      flattened_tags
    where 
      tag_key is not null 
      and tag_key <> ''
      and tag_value <> '""'
    order by 
      label;
  EOQ

  param "line_item_usage_account_id" {}
}
