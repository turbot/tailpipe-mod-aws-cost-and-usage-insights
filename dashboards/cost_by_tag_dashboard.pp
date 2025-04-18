dashboard "cost_by_tag_dashboard" {
  title         = "Cost and Usage Report: Cost by Tag"
  documentation = file("./dashboards/docs/cost_by_tag_dashboard.md")

  tags = {
    type    = "Dashboard"
    service = "AWS/CostAndUsageReport"
  }

  input "cost_by_tag_dashboard_accounts" {
    title       = "Select accounts:"
    description = "Choose one or more AWS accounts to analyze."
    type        = "multiselect"
    query       = query.cost_by_tag_dashboard_accounts_input
    width       = 4
  }

  input "cost_by_tag_dashboard_tag_key" {
    title       = "Select a tag key:"
    description = "Select a tag key to analyze costs by tag values."
    type        = "select"
    query       = query.cost_by_tag_dashboard_tag_key_input
    width       = 4
  }

  container {
    # Combined card showing Total Cost with Currency
    card {
      width = 2
      query = query.cost_by_tag_dashboard_total_cost
      icon  = "attach_money"
      type  = "info"

      args = {
        "account_ids" = self.input.cost_by_tag_dashboard_accounts.value
        "tag_key"     = self.input.cost_by_tag_dashboard_tag_key.value
      }
    }

    card {
      width = 2
      query = query.cost_by_tag_dashboard_total_accounts
      icon  = "groups"
      type  = "info"

      args = {
        "account_ids" = self.input.cost_by_tag_dashboard_accounts.value
      }
    }

  }

  container {
    # Cost Trend and Key/Value Breakdown
    chart {
      title = "Monthly Cost by Tag Value"
      type  = "column"
      width = 6
      query = query.cost_by_tag_dashboard_monthly_cost

      args = {
        "account_ids" = self.input.cost_by_tag_dashboard_accounts.value
        "tag_key"     = self.input.cost_by_tag_dashboard_tag_key.value
      }

      legend {
        display = "none"
      }
    }

    chart {
      title = "Top 10 Tag Values"
      type  = "table"
      width = 6
      query = query.cost_by_tag_dashboard_top_10_tag_values

      args = {
        "account_ids" = self.input.cost_by_tag_dashboard_accounts.value,
        "tag_key"     = self.input.cost_by_tag_dashboard_tag_key.value
      }
    }

  }

  container {
    # Detailed Tables
    table {
      title = "Tag Value Costs"
      width = 12
      query = query.cost_by_tag_dashboard_tag_value_costs

      args = {
        "account_ids" = self.input.cost_by_tag_dashboard_accounts.value
        "tag_key"     = self.input.cost_by_tag_dashboard_tag_key.value
      }
    }
  }
}

# Query Definitions

query "cost_by_tag_dashboard_total_cost" {
  sql = <<-EOQ
    with tagged_resources as (
      select 
        line_item_resource_id,
        line_item_unblended_cost,
        line_item_currency_code
      from 
        aws_cost_and_usage_report
      where 
        resource_tags is not null
        and array_contains(json_keys(resource_tags), $2)
        and json_extract(resource_tags, '$.' || $2) is not null
        and json_extract(resource_tags, '$.' || $2) <> '""'
        and ('all' in ($1) or line_item_usage_account_id in $1)
    )
    select
      'Total Cost (' || max(line_item_currency_code) || ')' as label,
      round(sum(line_item_unblended_cost), 2) as value
    from
      tagged_resources;
  EOQ

  param "account_ids" {}
  param "tag_key" {}

  tags = {
    folder = "Hidden"
  }
}

query "cost_by_tag_dashboard_total_accounts" {
  sql = <<-EOQ
    select
      'Accounts' as label,
      count(distinct line_item_usage_account_id) as value
    from
      aws_cost_and_usage_report
    where
      ('all' in ($1) or line_item_usage_account_id in $1);
  EOQ

  param "account_ids" {}

  tags = {
    folder = "Hidden"
  }
}


query "cost_by_tag_dashboard_monthly_cost" {
  sql = <<-EOQ
    with tagged_resources as (
      select
        line_item_resource_id,
        date_trunc('month', line_item_usage_start_date) as month,
        line_item_unblended_cost,
        json_extract(resource_tags, '$.' || $2) as tag_value
      from
        aws_cost_and_usage_report r
      where
        ('all' in ($1) or line_item_usage_account_id in $1)
        and resource_tags is not null
        and array_contains(json_keys(resource_tags), $2)
        and json_extract(resource_tags, '$.' || $2) is not null
        and json_extract(resource_tags, '$.' || $2) <> '""'
    )
    select
      strftime(month, '%b %Y') as "Month",
      replace(tag_value, '"', '') as "Series",
      round(sum(line_item_unblended_cost), 2) as "Total Cost"
    from
      tagged_resources
    group by
      month,
      tag_value
    having
      sum(line_item_unblended_cost) > 0
    order by
      month,
      sum(line_item_unblended_cost) desc;
  EOQ

  param "account_ids" {}
  param "tag_key" {}

  tags = {
    folder = "Hidden"
  }
}

query "cost_by_tag_dashboard_top_10_tag_values" {
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
        tag_key = $2
        and tag_value <> '""'
    ),
    tag_costs as (
      select
        replace(tag_value, '"', '') as tag_display,
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
    order by
      cost desc
    limit 10;
  EOQ

  param "account_ids" {}
  param "tag_key" {}

  tags = {
    folder = "Hidden"
  }
}

query "cost_by_tag_dashboard_tag_value_costs" {
  sql = <<-EOQ
    with parsed_entries as (
      select
        unnest(json_keys(resource_tags)) as tag_key,
        json_extract(resource_tags, '$.' || unnest(json_keys(resource_tags))) as tag_value,
        line_item_resource_id,
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
        line_item_resource_id,
        line_item_usage_account_id,
        line_item_unblended_cost,
        product_region_code
      from
        parsed_entries
      where
        tag_key = $2
        and tag_value <> '""'
    ),
    grouped_costs as (
      select
        replace(tag_value, '"', '') as tag_display,
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
      line_item_usage_account_id as "Account",
      region as "Region",
      round(cost, 2) as "Total Cost"
    from
      grouped_costs
    order by
      cost desc;
  EOQ

  param "account_ids" {}
  param "tag_key" {}

  tags = {
    folder = "Hidden"
  }
}

query "cost_by_tag_dashboard_accounts_input" {
  sql = <<-EOQ
    with account_ids as (
      select
        distinct on(line_item_usage_account_id)
        line_item_usage_account_id ||
        case
          when line_item_usage_account_name is not null then ' (' || coalesce(line_item_usage_account_name, '') || ')'
          else ''
        end as label,
        line_item_usage_account_id as value
      from
        aws_cost_and_usage_report
      order by label
    )
    select
      'All' as label,
      'all' as value
    union all
    select
      label,
      value
    from
      account_ids;
  EOQ

  tags = {
    folder = "Hidden"
  }
}

query "cost_by_tag_dashboard_tag_key_input" {
  sql = <<-EOQ
    select distinct
      t.tag_key as label,
      t.tag_key as value
    from
      aws_cost_and_usage_report,
      unnest(json_keys(resource_tags)) as t(tag_key)
    where
      resource_tags is not null
      and t.tag_key <> ''
      and json_extract(resource_tags, '$.' || t.tag_key) <> '""'
    order by
      label;
  EOQ

  tags = {
    folder = "Hidden"
  }
}
