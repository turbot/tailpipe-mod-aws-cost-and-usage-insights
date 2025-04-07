dashboard "cost_by_tag_key_dashboard" {
  title         = "Cost by Tag Key Dashboard"
  documentation = file("./dashboards/docs/cost_by_tag_key_dashboard.md")

  tags = {
    type    = "Dashboard"
    service = "AWS/CostAndUsageReport"
  }

  input "cost_by_tag_key_dashboard_accounts" {
    title       = "Select account(s):"
    description = "Select an AWS account to filter the dashboard."
    type        = "multiselect"
    query       = query.cost_by_tag_key_dashboard_accounts_input
    width       = 2
  }

  input "cost_by_tag_key_dashboard_tag_key" {
    title       = "Select a tag key:"
    description = "Select a tag key to analyze costs by tag values."
    type        = "select"
    query       = query.cost_by_tag_key_dashboard_tag_key_input
    width       = 2

    args = {
      "line_item_usage_account_id" = self.input.cost_by_tag_key_dashboard_accounts.value
    }
  }

  container {
    # Combined card showing Total Cost with Currency
    card {
      width = 4
      query = query.cost_by_tag_key_dashboard_total_cost
      icon  = "attach_money"
      type  = "info"

      args = {
        "line_item_usage_account_id" = self.input.cost_by_tag_key_dashboard_accounts.value
        "tag_key"                    = self.input.cost_by_tag_key_dashboard_tag_key.value
      }
    }
  }

  container {
    # Cost Trend and Key/Value Breakdown
    chart {
      title = "Monthly Cost by Tag Value"
      type  = "column"
      width = 6
      query = query.cost_by_tag_key_dashboard_monthly_cost
      args = {
        "line_item_usage_account_id" = self.input.cost_by_tag_key_dashboard_accounts.value
        "tag_key"                    = self.input.cost_by_tag_key_dashboard_tag_key.value
      }
      legend {
        display = "none"
      }
    }

    chart {
      title = "Top 10 Tag Values by Cost"
      type  = "table"
      width = 6
      query = query.cost_by_tag_key_dashboard_top_10_tag_values
      args = {
        "line_item_usage_account_id" = self.input.cost_by_tag_key_dashboard_accounts.value,
        "tag_key"                    = self.input.cost_by_tag_key_dashboard_tag_key.value
      }
    }
  }

  container {
    # Detailed Tables
    table {
      title = "Cost by Tag Value and Account"
      width = 12
      query = query.cost_by_tag_key_dashboard_tag_value_costs
      args = {
        "line_item_usage_account_id" = self.input.cost_by_tag_key_dashboard_accounts.value
        "tag_key"                    = self.input.cost_by_tag_key_dashboard_tag_key.value
      }
    }
  }
}

# Query Definitions

query "cost_by_tag_key_dashboard_total_cost" {
  sql = <<-EOQ
    with parsed_entries as (
      select
        unnest(json_keys(resource_tags)) as tag_key,
        line_item_unblended_cost,
        line_item_currency_code
      from aws_cost_and_usage_report
      where 
        resource_tags is not null
        and ('all' in ($1) or line_item_usage_account_id in $1)
    ),
    filtered_entries as (
      select
        sum(line_item_unblended_cost) as cost,
        max(line_item_currency_code) as currency
      from
        parsed_entries
      where
        $2 = 'all' or tag_key = $2
    )
    select 
      'Total Cost' as metric,
      concat(round(cost, 2), ' ', currency) as value
    from 
      filtered_entries;
  EOQ

  param "line_item_usage_account_id" {}
  param "tag_key" {}
  tags = {
    folder = "Hidden"
  }
}

query "cost_by_tag_key_dashboard_monthly_cost" {
  sql = <<-EOQ
    with parsed_entries as (
      select
        unnest(json_keys(resource_tags)) as tag_key,
        json_extract(resource_tags, '$.' || unnest(json_keys(resource_tags))) as tag_value,
        line_item_usage_start_date,
        line_item_usage_account_id,
        line_item_unblended_cost
      from 
        aws_cost_and_usage_report
      where 
        resource_tags is not null
        and ('all' in ($1) or line_item_usage_account_id in $1)
    ),
    filtered_entries as (
      select
        tag_key,
        tag_value,
        line_item_usage_start_date,
        line_item_unblended_cost
      from 
        parsed_entries
      where 
        ($2 = 'all' or tag_key = $2)
        and tag_value <> '""'
    ),
    tag_costs as (
      select 
        date_trunc('month', line_item_usage_start_date) as month,
        case 
          when $2 = 'all' then concat(tag_key, ': ', replace(tag_value, '"', ''))
          else replace(tag_value, '"', '')
        end as series,
        sum(line_item_unblended_cost) as cost
      from 
        filtered_entries
      group by 
        date_trunc('month', line_item_usage_start_date),
        series
    )
    select 
      strftime(month, '%b %Y') as "Month",
      series as "Series",
      round(cost, 2) as "Total Cost"
    from 
      tag_costs
    order by 
      month,
      cost desc
    limit 30;
  EOQ

  param "line_item_usage_account_id" {}
  param "tag_key" {}
  tags = {
    folder = "Hidden"
  }
}

query "cost_by_tag_key_dashboard_top_10_tag_values" {
  sql = <<-EOQ
    with parsed_entries as (
      select
        unnest(json_keys(resource_tags)) as tag_key,
        json_extract(resource_tags, '$.' || unnest(json_keys(resource_tags))) as tag_value,
        line_item_usage_account_id,
        line_item_unblended_cost
      from 
        aws_cost_and_usage_report
      where
        resource_tags is not null
        and ('all' in ($1) or line_item_usage_account_id in $1)
    ),
    filtered_entries as (
      select
        tag_key,
        tag_value,
        line_item_unblended_cost
      from 
        parsed_entries
      where 
        ($2 = 'all' or tag_key = $2)
        and tag_value <> '""'
    ),
    tag_costs as (
      select 
        case 
          when $2 = 'all' then concat(tag_key, ': ', replace(tag_value, '"', ''))
          else replace(tag_value, '"', '')
        end as tag_display,
        sum(line_item_unblended_cost) as cost
      from 
        filtered_entries
      group by 
        tag_display
    )
    select 
      tag_display as "Tag Value",
      round(cost, 2) as "Total Cost"
    from 
      tag_costs
    order by cost desc
    limit 10;
  EOQ

  param "line_item_usage_account_id" {}
  param "tag_key" {}
  tags = {
    folder = "Hidden"
  }
}

query "cost_by_tag_key_dashboard_tag_value_costs" {
  sql = <<-EOQ
    with parsed_entries as (
      select
        unnest(json_keys(resource_tags)) as tag_key,
        json_extract(resource_tags, '$.' || unnest(json_keys(resource_tags))) as tag_value,
        line_item_usage_account_id,
        line_item_unblended_cost,
        product_region_code
      from 
        aws_cost_and_usage_report
      where
        resource_tags is not null
        and ('all' in ($1) or line_item_usage_account_id in $1)
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
        ($2 = 'all' or tag_key = $2)
        and tag_value <> '""'
    ),
    grouped_costs as (
      select
        case 
          when $2 = 'all' then concat(tag_key, ': ', replace(tag_value, '"', ''))
          else replace(tag_value, '"', '')
        end as tag_display,
        line_item_usage_account_id,
        coalesce(product_region_code, 'global') as region,
        sum(line_item_unblended_cost) as cost
      from 
        filtered_entries
      group by 
        tag_display,
        line_item_usage_account_id,
        region
    )
    select 
      tag_display as "Tag Value",
      line_item_usage_account_id as "Account ID",
      region as "Region",
      round(cost, 2) as "Total Cost"
    from 
      grouped_costs
    order by 
      cost desc
    limit 30;
  EOQ

  param "line_item_usage_account_id" {}
  param "tag_key" {}
  tags = {
    folder = "Hidden"
  }
}

query "cost_by_tag_key_dashboard_accounts_input" {
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
  tags = {
    folder = "Hidden"
  }
}

query "cost_by_tag_key_dashboard_tag_key_input" {
  sql = <<-EOQ
    select distinct
      t.tag_key as label,
      t.tag_key as value
    from
      aws_cost_and_usage_report,
      unnest(json_keys(resource_tags)) as t(tag_key)
    where
      line_item_usage_account_id in $1
      and resource_tags is not null
      and t.tag_key <> ''
      and json_extract(resource_tags, '$.' || t.tag_key) <> '""'
    order by
      label;
  EOQ

  param "line_item_usage_account_id" {}
  tags = {
    folder = "Hidden"
  }
}
