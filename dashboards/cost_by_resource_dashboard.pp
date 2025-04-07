dashboard "cost_by_resource_dashboard" {
  title         = "Cost by Resource Dashboard"
  documentation = file("./dashboards/docs/cost_by_resource_dashboard.md")

  tags = {
    type    = "Dashboard"
    service = "AWS/CostAndUsageReport"
  }

  input "cost_by_resource_dashboard_account" {
    title       = "Select account(s):"
    description = "Select an AWS account to filter the dashboard."
    type        = "multiselect"
    query       = query.cost_by_resource_dashboard_aws_account_input
    width       = 2
  }

  container {
    # Combined card showing Total Cost with Currency
    card {
      width = 2
      query = query.cost_by_resource_dashboard_total_cost
      icon  = "attach_money"
      type  = "info"

      args = {
        "line_item_usage_account_id" = self.input.cost_by_resource_dashboard_account.value
      }
    }

    card {
      width = 2
      query = query.cost_by_resource_dashboard_total_accounts
      type  = "info"

      args = {
        "line_item_usage_account_id" = self.input.cost_by_resource_dashboard_account.value
      }
    }

    card {
      width = 2
      query = query.cost_by_resource_dashboard_total_resources
      type  = "info"

      args = {
        "line_item_usage_account_id" = self.input.cost_by_resource_dashboard_account.value
      }
    }
  }

  container {
    # Cost Trend and Top Resources
    chart {
      title = "Monthly Cost Trend"
      type  = "line"
      width = 6
      query = query.cost_by_resource_dashboard_monthly_cost
      args = {
        "line_item_usage_account_id" = self.input.cost_by_resource_dashboard_account.value
      }

      legend {
        display = "none"
      }
    }


    chart {
      title = "Daily Cost Trend (Last 30 Days)"
      width = 6
      type  = "line"
      query = query.cost_by_resource_dashboard_daily_cost

      args = {
        "line_item_usage_account_id" = self.input.cost_by_resource_dashboard_account.value
      }

      legend {
        display = "none"
      }
    }

    chart {
      title = "Top 10 Resources"
      type  = "table"
      width = 6
      query = query.cost_by_resource_dashboard_top_10_resources
      args = {
        "line_item_usage_account_id" = self.input.cost_by_resource_dashboard_account.value
      }
    }
  }

  container {
    # Detailed Table
    table {
      title = "Resource Costs"
      width = 12
      query = query.cost_by_resource_dashboard_resource_costs
      args = {
        "line_item_usage_account_id" = self.input.cost_by_resource_dashboard_account.value
      }
    }
  }
}

# Query Definitions

query "cost_by_resource_dashboard_total_cost" {
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

query "cost_by_resource_dashboard_total_accounts" {
  sql = <<-EOQ
    select
      'Accounts' as label,
      count(distinct line_item_usage_account_id) as value
    from
      aws_cost_and_usage_report
    where
      ('all' in ($1) or line_item_usage_account_id in $1)
      and line_item_resource_id is not null;
  EOQ

  param "line_item_usage_account_id" {}
  tags = {
    folder = "Hidden"
  }
}

query "cost_by_resource_dashboard_total_resources" {
  sql = <<-EOQ
    select
      'Resources' as label,
      count(distinct line_item_resource_id) as value
    from
      aws_cost_and_usage_report
    where
      ('all' in ($1) or line_item_usage_account_id in $1)
      and line_item_resource_id is not null;
  EOQ

  param "line_item_usage_account_id" {}
  tags = {
    folder = "Hidden"
  }
}


query "cost_by_resource_dashboard_monthly_cost" {
  sql = <<-EOQ
    select 
      strftime(date_trunc('month', line_item_usage_start_date), '%b %Y') as "Month",
      line_item_resource_id as "Resource",
      round(sum(line_item_unblended_cost), 2) as "Total Cost"
    from 
      aws_cost_and_usage_report
    where 
      ('all' in ($1) or line_item_usage_account_id in $1)
      and line_item_resource_id is not null
    group by 
      date_trunc('month', line_item_usage_start_date),
      line_item_resource_id
    order by 
      date_trunc('month', line_item_usage_start_date),
      sum(line_item_unblended_cost) desc
    limit 10;
  EOQ

  param "line_item_usage_account_id" {}
  tags = {
    folder = "Hidden"
  }
}

query "cost_by_resource_dashboard_daily_cost" {
  sql = <<-EOQ
    select
      strftime(date_trunc('day', line_item_usage_start_date), '%d-%m-%Y') as "Date",
      line_item_resource_id as "Resource",
      round(sum(line_item_unblended_cost), 2) as "Total Cost"
    from
      aws_cost_and_usage_report
    where
      line_item_usage_start_date >= current_date - interval '30' day
      and ('all' in ($1) or line_item_usage_account_id in $1)
      and line_item_resource_id is not null
    group by
      date_trunc('day', line_item_usage_start_date),
      line_item_resource_id
    order by
      date_trunc('day', line_item_usage_start_date)
    limit 30;
  EOQ

  param "line_item_usage_account_id" {}
  tags = {
    folder = "Hidden"
  }
}

query "cost_by_resource_dashboard_top_10_resources" {
  sql = <<-EOQ
    select 
      line_item_resource_id as "Resource",
      line_item_usage_account_id as "Account",
      line_item_product_code as "Service",
      coalesce(product_region_code, 'global') as "Region",
      round(sum(line_item_unblended_cost), 2) as "Total Cost"
    from 
      aws_cost_and_usage_report
    where 
      ('all' in ($1) or line_item_usage_account_id in $1)
      and line_item_resource_id is not null
    group by 
      line_item_resource_id,
      line_item_usage_account_id,
      line_item_product_code,
      coalesce(product_region_code, 'global')
    order by 
      sum(line_item_unblended_cost) desc
    limit 10;
  EOQ

  param "line_item_usage_account_id" {}
  tags = {
    folder = "Hidden"
  }
}

query "cost_by_resource_dashboard_resource_costs" {
  sql = <<-EOQ
    select
      line_item_resource_id as "Resource",
      line_item_product_code as "Service",
      line_item_usage_account_id as "Account",
      coalesce(product_region_code, 'global') as "Region",
      round(sum(line_item_unblended_cost), 2) as "Total Cost"
    from 
      aws_cost_and_usage_report
    where 
      ('all' in ($1) or line_item_usage_account_id in $1)
      and line_item_resource_id is not null
    group by 
      line_item_resource_id,
      line_item_product_code,
      coalesce(product_region_code, 'global'),
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

query "cost_by_resource_dashboard_aws_account_input" {
  sql = <<-EOQ
    select
      'All' as label,
      'all' as value
    union all
    select 
      distinct line_item_usage_account_id as label,
      line_item_usage_account_id as value
    from 
      aws_cost_and_usage_report;
  EOQ
  tags = {
    folder = "Hidden"
  }
}
