dashboard "cost_by_tag_dashboard" {
  title         = "Cost by Tag Dashboard"
  documentation = file("./dashboards/docs/cost_by_tag_dashboard.md")

  tags = {
    type    = "Dashboard"
    service = "AWS/CostAndUsageReport"
  }

  input "cost_by_tag_dashboard_accounts" {
    title       = "Select account(s):"
    description = "Select an AWS account to filter the dashboard."
    type        = "multiselect"
    query       = query.cost_by_tag_dashboard_accounts_input
    width       = 2
  }

  container {
    # Combined card showing Total Cost with Currency
    card {
      width = 2
      query = query.cost_by_tag_dashboard_total_cost
      icon  = "attach_money"
      type  = "info"

      args = {
        "line_item_usage_account_id" = self.input.cost_by_tag_dashboard_accounts.value
      }
    }

    card {
      width = 2
      query = query.cost_by_tag_dashboard_total_accounts
      type  = "info"

      args = {
        "line_item_usage_account_id" = self.input.cost_by_tag_dashboard_accounts.value
      }
    }

    card {
      width = 2
      query = query.cost_by_tag_dashboard_total_tags
      icon  = "label"
      type  = "info"

      args = {
        "line_item_usage_account_id" = self.input.cost_by_tag_dashboard_accounts.value
      }
    }
  }

  container {
    # Cost Trend and Key/Value Breakdown
    chart {
      title = "Monthly Cost Trend"
      type  = "line"
      width = 6
      query = query.cost_by_tag_dashboard_monthly_cost_trend
      args = {
        "line_item_usage_account_id" = self.input.cost_by_tag_dashboard_accounts.value
      }

      legend {
        display = "none"
      }

      series "Total Cost" {
        title = "Tag Costs"
      }
    }

    chart {
      title = "Daily Cost Trend (Last 30 Days)"
      type  = "line"
      width = 6
      query = query.cost_by_tag_dashboard_daily_cost_trend

      args = {
        "line_item_usage_account_id" = self.input.cost_by_tag_dashboard_accounts.value
      }

      legend {
        display = "none"
      }
    }

    chart {
      title = "Top 10 Tags by Cost"
      type  = "table"
      width = 6
      query = query.cost_by_tag_dashboard_top_10_tags_by_cost
      args = {
        "line_item_usage_account_id" = self.input.cost_by_tag_dashboard_accounts.value
      }
    }
  }

  container {
    # Detailed Table
    table {
      title = "Tag Costs by Account and Region"
      width = 12
      query = query.cost_by_tag_dashboard_tagged_resources
      args = {
        "line_item_usage_account_id" = self.input.cost_by_tag_dashboard_accounts.value
      }
    }
  }

  container {
    # Untagged Resources Table
    table {
      title = "Untagged Resource Costs"
      width = 12
      query = query.cost_by_tag_dashboard_untagged_resources
      args = {
        "line_item_usage_account_id" = self.input.cost_by_tag_dashboard_accounts.value
      }
    }
  }
}

# Query Definitions

query "cost_by_tag_dashboard_total_cost" {
  sql = <<-EOQ
    select 
      'Total Cost (' || line_item_currency_code || ')' as label,
      round(sum(line_item_unblended_cost), 2) as value
    from 
      aws_cost_and_usage_report
    where 
      ('all' in ($1) or line_item_usage_account_id in $1)
    group by
      line_item_currency_code
    limit 1;
  EOQ

  param "line_item_usage_account_id" {}
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
      ('all' in ($1) or line_item_usage_account_id in $1)
      and resource_tags is not null;
  EOQ

  param "line_item_usage_account_id" {}
  tags = {
    folder = "Hidden"
  }
}

query "cost_by_tag_dashboard_total_tags" {
  sql = <<-EOQ
    with all_tags as (
      select
        unnest(json_keys(resource_tags)) as tag_key
      from
        aws_cost_and_usage_report
      where
        ('all' in ($1) or line_item_usage_account_id in $1)
        and resource_tags is not null
    )
    select
      'Tags' as label,
      count(distinct tag_key) as value
    from
      all_tags;
  EOQ

  param "line_item_usage_account_id" {}
  tags = {
    folder = "Hidden"
  }
}

query "cost_by_tag_dashboard_monthly_cost_trend" {
  sql = <<-EOQ
    with parsed_entries as (
      select 
        distinct unnest(json_keys(resource_tags)) as tag_key,
        json_extract(resource_tags, '$.' || unnest(json_keys(resource_tags))) as tag_value,
        line_item_usage_start_date,
        line_item_usage_account_id,
        line_item_unblended_cost
      from 
        aws_cost_and_usage_report
      where
        resource_tags is not null
    ),
    formatted_entries as (
      select
        tag_key,
        tag_value,
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
        concat(tag_key, ': ', tag_value) as tag,
        sum(line_item_unblended_cost) as cost
      from 
        formatted_entries
      where
        tag_value <> '""'
      group by 
        date_trunc('month', line_item_usage_start_date),
        tag_key,
        tag_value
    )
    select 
      strftime(month, '%b %Y') as "Month",
      tag as "Series",
      round(cost, 2) as "Total Cost"
    from 
      tag_costs
    order by 
      month, cost desc
    limit 30;
  EOQ

  param "line_item_usage_account_id" {}
  tags = {
    folder = "Hidden"
  }
}

query "cost_by_tag_dashboard_daily_cost_trend" {
  sql = <<-EOQ
    with parsed_entries as (
      select 
        distinct unnest(json_keys(resource_tags)) as tag_key,
        json_extract(resource_tags, '$.' || unnest(json_keys(resource_tags))) as tag_value,
        line_item_usage_start_date,
        line_item_usage_account_id,
        line_item_unblended_cost
      from 
        aws_cost_and_usage_report
      where 
        resource_tags is not null
    ),
    formatted_entries as (
      select
        tag_key,
        tag_value,
        line_item_usage_start_date,
        line_item_unblended_cost
      from 
        parsed_entries
      where 
        ('all' in ($1) or line_item_usage_account_id in $1)
    ),
    tag_costs as (
      select 
        date_trunc('day', line_item_usage_start_date) as day,
        concat(tag_key, ': ', tag_value) as tag,
        sum(line_item_unblended_cost) as cost
      from 
        formatted_entries
      where 
        tag_value <> '""'
      group by 
        date_trunc('day', line_item_usage_start_date),
        tag_key,
        tag_value
    )
    select 
      strftime(day, '%d-%m-%Y') as "Date",
      tag as "Series",
      round(cost, 2) as "Total Cost"
    from 
      tag_costs
    where
      day >= current_date - interval '30' day
    order by 
      day, cost desc
    limit 30;
  EOQ

  param "line_item_usage_account_id" {}
  tags = {
    folder = "Hidden"
  }
}

query "cost_by_tag_dashboard_top_10_tags_by_cost" {
  sql = <<-EOQ
    with parsed_entries as (
    select 
      distinct unnest(json_keys(resource_tags)) as tag_key,
      json_extract(resource_tags, '$.' || unnest(json_keys(resource_tags))) as tag_value,
      line_item_usage_account_id,
      line_item_unblended_cost
    from aws_cost_and_usage_report
    where resource_tags is not null
    ),
    formatted_entries as (
      select
        tag_key,
        tag_value,
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
        tag_value,
        original_value,
        sum(line_item_unblended_cost) as cost
      from 
        formatted_entries
      where
        tag_value <> '""'
      group by 
        tag_key,
        tag_value,
        original_value
    )
    select 
      concat(tag_key, ': ', tag_value) as "Tag",
      round(cost, 2) as "Total Cost"
    from 
      tag_costs
    order by cost desc
    limit 10;

  EOQ

  param "line_item_usage_account_id" {}
  tags = {
    folder = "Hidden"
  }
}

query "cost_by_tag_dashboard_tagged_resources" {
  sql = <<-EOQ
    with parsed_entries as (
    select 
      distinct unnest(json_keys(resource_tags)) as tag_key,
      json_extract(resource_tags, '$.' || unnest(json_keys(resource_tags))) as tag_value,
      line_item_usage_account_id,
      line_item_unblended_cost,
      product_region_code,
      line_item_usage_account_id,
      line_item_resource_id,
      line_item_product_code
    from 
      aws_cost_and_usage_report
    where 
      resource_tags is not null
    ),
    formatted_entries as (
      select
        tag_key,
        tag_value,
        line_item_unblended_cost,
        line_item_usage_account_id,
        line_item_resource_id,
        line_item_product_code,
        product_region_code
      from 
        parsed_entries
      where 
        ('all' in ($1) or line_item_usage_account_id in $1)
    )
    select 
      concat(tag_key, ': ', tag_value) as "Tag",
      line_item_usage_account_id as "Account",
      coalesce(product_region_code, 'global') as "Region",
      round(sum(line_item_unblended_cost), 2) as "Total Cost"
    from 
      formatted_entries
    where
      tag_value <> '""'
    group by 
      concat(tag_key, ': ', tag_value),
      line_item_usage_account_id,
      product_region_code
    order by sum(line_item_unblended_cost) desc
    limit 30;
  EOQ

  param "line_item_usage_account_id" {}
  tags = {
    folder = "Hidden"
  }
}

query "cost_by_tag_dashboard_untagged_resources" {
  sql = <<-EOQ
    with resource_tags_exploded as (
      -- Explode all tags for each resource
      select 
        line_item_resource_id,
        line_item_product_code,
        product_region_code,
        line_item_usage_account_id,
        line_item_unblended_cost,
        unnest(json_keys(resource_tags)) as tag_key,
        json_extract(resource_tags, '$.' || unnest(json_keys(resource_tags))) as tag_value
      from 
        aws_cost_and_usage_report
      where 
        resource_tags is not null
        and line_item_resource_id is not null
    ), 
    tag_status_by_resource as (
      -- Check if all tags for each resource have empty values
      select 
        line_item_resource_id,
        line_item_product_code,
        product_region_code,
        line_item_usage_account_id,
        line_item_unblended_cost,
        case when bool_and(tag_value = '""' or tag_value is null) then true else false end as all_tags_empty
      from 
        resource_tags_exploded
      group by
        line_item_resource_id,
        line_item_product_code,
        product_region_code,
        line_item_usage_account_id,
        line_item_unblended_cost
    ), 
    combined_resources as (
      -- Resources with all empty tags
      select 
        line_item_resource_id,
        line_item_product_code,
        product_region_code,
        line_item_usage_account_id,
        line_item_unblended_cost
      from 
        tag_status_by_resource
      where 
        all_tags_empty = true

      union all

      -- Resources with no tags at all
      select 
        line_item_resource_id,
        line_item_product_code,
        product_region_code,
        line_item_usage_account_id,
        line_item_unblended_cost
      from 
        aws_cost_and_usage_report
      where 
        (resource_tags is null or resource_tags = '{}')
        and line_item_resource_id is not null
    )
    select 
      line_item_resource_id as "Resource",
      line_item_product_code as "Service",
      line_item_usage_account_id as "Account",
      case
        when line_item_resource_id like 'arn:aws%' then
          case
            when split_part(line_item_resource_id, ':', 4) = '' or split_part(line_item_resource_id, ':', 4) is null then 'global'
            else split_part(line_item_resource_id, ':', 4)
          end
        else
          coalesce(product_region_code, 'global')
      end as "Region",
      round(sum(line_item_unblended_cost), 2) as "Total Cost"
    from 
      combined_resources
    where 
      ('all' in ($1) or line_item_usage_account_id in $1)  -- Account filter parameter
    group by 
      line_item_resource_id,
      line_item_product_code,
      product_region_code,
      line_item_usage_account_id
    order by 
      sum(line_item_unblended_cost) desc
    limit 30;
  EOQ

  param "line_item_usage_account_id" {}
  tags = {
    folder = "Hidden"
  }
}

query "cost_by_tag_dashboard_accounts_input" {
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
