dashboard "overview_dashboard" {
  title         = "Cost and Usage Overview Dashboard"
  documentation = file("./dashboards/docs/overview_dashboard.md")

  tags = {
    type    = "Dashboard"
    service = "AWS/CostAndUsageReport"
  }

  container {
    # Multi-select Account Input
    input "overview_dashboard_accounts" {
      title       = "Select account(s):"
      description = "Choose one or more AWS accounts to analyze."
      type        = "multiselect"
      width       = 2
      query       = query.overview_dashboard_accounts_input
    }
  }

  container {
    # Summary Metrics
    # Combined card showing Total Cost with Currency
    card {
      width = 2
      query = query.overview_dashboard_total_cost
      icon  = "attach_money"
      type  = "info"

      args = {
        "line_item_usage_account_ids" = self.input.overview_dashboard_accounts.value
      }
    }
    # Card showing Total Accounts
    card {
      width = 2
      query = query.overview_dashboard_total_accounts
      icon  = "groups"
      type  = "info"

      args = {
        "line_item_usage_account_ids" = self.input.overview_dashboard_accounts.value
      }
    }

  }

  container {
    # Graphs
    chart {
      title = "Monthly Cost Trend"
      type  = "line"
      width = 6
      query = query.overview_dashboard_monthly_cost
      args = {
        "line_item_usage_account_ids" = self.input.overview_dashboard_accounts.value
      }

      legend {
        display = "none"
      }
    }

    chart {
      title = "Daily Cost Trend (Last 30 Days)"
      type  = "line"
      width = 6
      query = query.overview_dashboard_daily_cost
      args = {
        "line_item_usage_account_ids" = self.input.overview_dashboard_accounts.value
      }

      legend {
        display = "none"
      }
    }

  }

  container {
    # Tables
    chart {
      title = "Top 10 Accounts"
      type  = "table"
      width = 6
      query = query.overview_dashboard_top_10_accounts
      args = {
        "line_item_usage_account_ids" = self.input.overview_dashboard_accounts.value
      }
    }

    chart {
      title = "Top 10 Regions"
      type  = "table"
      width = 6
      query = query.overview_dashboard_top_10_regions
      args = {
        "line_item_usage_account_ids" = self.input.overview_dashboard_accounts.value
      }
    }

    chart {
      title = "Top 10 Services"
      type  = "table"
      width = 6
      query = query.overview_dashboard_top_10_services
      args = {
        "line_item_usage_account_ids" = self.input.overview_dashboard_accounts.value
      }
    }

    chart {
      title = "Top 10 Resources"
      type  = "table"
      width = 6
      query = query.overview_dashboard_top_10_resources
      args = {
        "line_item_usage_account_ids" = self.input.overview_dashboard_accounts.value
      }
    }
  }
}

# Queries

query "overview_dashboard_total_cost" {
  sql = <<-EOQ
    select
      'Total Cost (' || line_item_currency_code || ')' as label,
      round(sum(line_item_unblended_cost), 2) as value
    from
      aws_cost_and_usage_report
    where
      ('all' in ($1) or line_item_usage_account_id in $1)
    group by
      line_item_currency_code;
  EOQ
  param "line_item_usage_account_ids" {}
  tags = {
    folder = "Hidden"
  }
}

query "overview_dashboard_total_accounts" {
  sql = <<-EOQ
    select
      'Total Accounts' as label,
      count(distinct line_item_usage_account_id) as value
    from
      aws_cost_and_usage_report
    where
      ('all' in ($1) or line_item_usage_account_id in $1);
  EOQ

  param "line_item_usage_account_ids" {}
  tags = {
    folder = "Hidden"
  }
}

query "overview_dashboard_monthly_cost" {
  sql = <<-EOQ
    select
      strftime(date_trunc('month', line_item_usage_start_date), '%b %Y') as "Month",
      round(sum(line_item_unblended_cost), 2) as "Total Cost"
    from
      aws_cost_and_usage_report
    where
      line_item_usage_start_date >= current_date - interval '6' month
      and ('all' in ($1) or line_item_usage_account_id in $1)
    group by
      date_trunc('month', line_item_usage_start_date)
    order by
      date_trunc('month', line_item_usage_start_date);
  EOQ
  param "line_item_usage_account_ids" {}
  tags = {
    folder = "Hidden"
  }
}

query "overview_dashboard_daily_cost" {
  sql = <<-EOQ
    select
      strftime(date_trunc('day', line_item_usage_start_date), '%d-%m-%Y') as "Date",
      round(sum(line_item_unblended_cost), 2) as "Total Cost"
    from
      aws_cost_and_usage_report
    where
      line_item_usage_start_date >= current_date - interval '30' day
      and ('all' in ($1) or line_item_usage_account_id in $1)
    group by
      date_trunc('day', line_item_usage_start_date)
    order by
      date_trunc('day', line_item_usage_start_date);
  EOQ
  param "line_item_usage_account_ids" {}
  tags = {
    folder = "Hidden"
  }
}

query "overview_dashboard_top_10_accounts" {
  sql = <<-EOQ
    select
      line_item_usage_account_id as "Account",
      printf('%.2f', sum(line_item_unblended_cost)) as "Total Cost"
    from
      aws_cost_and_usage_report
    where
      ('all' in ($1) or line_item_usage_account_id in $1)
    group by
      "Account"
    order by
      sum(line_item_unblended_cost) desc
    limit 10;
  EOQ

  param "line_item_usage_account_ids" {}
  tags = {
    folder = "Hidden"
  }
}

query "overview_dashboard_top_10_regions" {
  sql = <<-EOQ
    select
      coalesce(product_region_code, 'global') as "Region",
      printf('%.2f', sum(line_item_unblended_cost)) as "Total Cost"
    from
      aws_cost_and_usage_report
    where
      ('all' in ($1) or line_item_usage_account_id in $1)
    group by
      "Region"
    order by
      "Total Cost" desc
    limit 10;
  EOQ

  param "line_item_usage_account_ids" {}
  tags = {
    folder = "Hidden"
  }
}

query "overview_dashboard_top_10_services" {
  sql = <<-EOQ
    select
      product_service_code as "Service",
      printf('%.2f', sum(line_item_unblended_cost)) as "Total Cost"
    from
      aws_cost_and_usage_report
    where
      ('all' in ($1) or line_item_usage_account_id in $1)
    group by
      product_service_code
    order by
      sum(line_item_unblended_cost) desc
    limit 10;
  EOQ
  param "line_item_usage_account_ids" {}
  tags = {
    folder = "Hidden"
  }
}

query "overview_dashboard_top_10_resources" {
  sql = <<-EOQ
    select
      line_item_resource_id as "Resource",
      line_item_usage_account_id as "Account",
      coalesce(product_region_code, 'global') as "Region",
      printf('%.2f', sum(line_item_unblended_cost)) as "Total Cost"
    from
      aws_cost_and_usage_report
    where
      ('all' in ($1)  or line_item_usage_account_id in $1)
      and line_item_resource_id is not null
    group by
      line_item_resource_id,
      line_item_usage_account_id,
      coalesce(product_region_code, 'global')
    order by
      sum(line_item_unblended_cost) desc
    limit 10;
  EOQ
  param "line_item_usage_account_ids" {}
  tags = {
    folder = "Hidden"
  }
}

query "overview_dashboard_accounts_input" {
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
