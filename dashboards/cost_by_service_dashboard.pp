dashboard "cost_by_service_dashboard" {
  title         = "Cost by Service Dashboard"
  documentation = file("./dashboards/docs/cost_by_service_dashboard.md")

  tags = {
    type    = "Dashboard"
    service = "AWS/CostAndUsageReport"
  }

  input "cost_by_service_dashboard_accounts" {
    title       = "Select accounts:"
    description = "Choose a single AWS account to analyze"
    type        = "multiselect"
    width       = 2
    query       = query.cost_by_service_dashboard_accounts_input
  }

  container {
    # Combined card showing Total Cost with Currency
    card {
      width = 2
      query = query.cost_by_service_dashboard_total_cost
      icon  = "attach_money"
      type  = "info"

      args = {
        "account_id" = self.input.cost_by_service_dashboard_accounts.value
      }
    }

    card {
      width = 2
      query = query.cost_by_service_dashboard_total_accounts
      type  = "info"

      args = {
        "account_id" = self.input.cost_by_service_dashboard_accounts.value
      }
    }

    card {
      width = 2
      query = query.cost_by_service_dashboard_total_services
      type  = "info"

      args = {
        "account_id" = self.input.cost_by_service_dashboard_accounts.value
      }
    }
  }

  container {
    # Cost Trend Graphs
    chart {
      title = "Monthly Cost Trend"
      type  = "line"
      width = 6
      query = query.cost_by_service_dashboard_monthly_cost
      args = {
        "account_id" = self.input.cost_by_service_dashboard_accounts.value
      }

      legend {
        display = "none"
      }
    }

    chart {
      title = "Daily Cost Trend (Last 30 Days)"
      type  = "line"
      width = 6
      query = query.cost_by_service_dashboard_daily_cost

      args = {
        "account_id" = self.input.cost_by_service_dashboard_accounts.value
      }

      legend {
        display = "none"
      }
    }

    chart {
      title = "Top 10 Services by Cost"
      type  = "table"
      width = 6
      query = query.cost_by_service_dashboard_top_10_services
      args = {
        "account_id" = self.input.cost_by_service_dashboard_accounts.value
      }
    }
  }

  container {
    # Detailed Table
    table {
      title = "Service Costs by Account"
      width = 12
      query = query.cost_by_service_dashboard_service_costs
      args = {
        "account_id" = self.input.cost_by_service_dashboard_accounts.value
      }
    }
  }
}

# Query Definitions

query "cost_by_service_dashboard_total_cost" {
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

  param "account_id" {}
  tags = {
    folder = "Hidden"
  }
}

query "cost_by_service_dashboard_total_accounts" {
  sql = <<-EOQ
    select
      'Accounts' as label,
      count(distinct line_item_usage_account_id) as value
    from
      aws_cost_and_usage_report
    where
      ('all' in ($1) or line_item_usage_account_id in $1);
  EOQ

  param "account_id" {}
  tags = {
    folder = "Hidden"
  }
}

query "cost_by_service_dashboard_total_services" {
  sql = <<-EOQ
    select
      'Services' as label,
      count(distinct line_item_product_code) as value
    from
      aws_cost_and_usage_report
    where
      ('all' in ($1) or line_item_usage_account_id in $1);
  EOQ

  param "account_id" {}
  tags = {
    folder = "Hidden"
  }
}

query "cost_by_service_dashboard_monthly_cost" {
  sql = <<-EOQ
    select 
      strftime(date_trunc('month', line_item_usage_start_date), '%b %Y') as "Month",
      line_item_product_code as "Service",
      round(sum(line_item_unblended_cost), 2) as "Total Cost"
    from 
      aws_cost_and_usage_report
    where 
      ('all' in ($1) or line_item_usage_account_id in $1)
      and line_item_usage_start_date >= current_date - interval '6' month
    group by 
      date_trunc('month', line_item_usage_start_date),
      line_item_product_code
    order by 
      date_trunc('month', line_item_usage_start_date),
      sum(line_item_unblended_cost) desc;
  EOQ

  param "account_id" {}
  tags = {
    folder = "Hidden"
  }
}

query "cost_by_service_dashboard_daily_cost" {
  sql = <<-EOQ
    select
      strftime(date_trunc('day', line_item_usage_start_date), '%d-%m-%Y') as "Date",
      line_item_product_code as "Service",
      round(sum(line_item_unblended_cost), 2) as "Total Cost"
    from
      aws_cost_and_usage_report
    where
      line_item_usage_start_date >= current_date - interval '30' day
      and ('all' in ($1) or line_item_usage_account_id in $1)
    group by
      date_trunc('day', line_item_usage_start_date),
      line_item_product_code
    order by
      date_trunc('day', line_item_usage_start_date);
  EOQ

  param "account_id" {}
  tags = {
    folder = "Hidden"
  }
}


query "cost_by_service_dashboard_top_10_services" {
  sql = <<-EOQ
    select 
      line_item_product_code as "Service",
      printf('%.2f', sum(line_item_unblended_cost)) as "Total Cost"
    from 
      aws_cost_and_usage_report
    where 
      ('all' in ($1) or line_item_usage_account_id in $1)
    group by 
      line_item_product_code
    order by 
      sum(line_item_unblended_cost) desc
    limit 10;
  EOQ

  param "account_id" {}
  tags = {
    folder = "Hidden"
  }
}

query "cost_by_service_dashboard_service_costs" {
  sql = <<-EOQ
    select 
      line_item_product_code as "Service",
      line_item_usage_account_id as "Account",
      coalesce(product_region_code, 'global') as "Region",
      printf('%.2f', sum(line_item_unblended_cost)) as "Total Cost"
    from 
      aws_cost_and_usage_report
    where 
      ('all' in ($1) or line_item_usage_account_id in $1)
    group by 
      line_item_product_code,
      line_item_usage_account_id,
      coalesce(product_region_code, 'global')
    order by 
      sum(line_item_unblended_cost) desc;
  EOQ

  param "account_id" {}
  tags = {
    folder = "Hidden"
  }
}

query "cost_by_service_dashboard_accounts_input" {
  sql = <<-EOQ
    select
      'All' as label,
      'all' as value
    union all
    select distinct line_item_usage_account_id as label,
      line_item_usage_account_id as value
    from aws_cost_and_usage_report;
  EOQ
  tags = {
    folder = "Hidden"
  }
}
