dashboard "cost_by_region_dashboard" {
  title         = "Cost and Usage Report: Cost by Region"
  documentation = file("./dashboards/docs/cost_by_region_dashboard.md")

  tags = {
    type    = "Dashboard"
    service = "AWS/CostAndUsageReport"
  }

  container {
    # Multi-select Account Input
    input "cost_by_region_dashboard_accounts" {
      title       = "Select accounts:"
      description = "Choose one or more AWS accounts to analyze."
      type        = "multiselect"
      width       = 4
      query       = query.cost_by_region_dashboard_accounts_input
    }
  }

  container {
    # Combined card showing Total Cost with Currency
    card {
      width = 2
      query = query.cost_by_region_dashboard_total_cost
      icon  = "attach_money"
      type  = "info"

      args = {
        "account_ids" = self.input.cost_by_region_dashboard_accounts.value
      }
    }

    card {
      width = 2
      query = query.cost_by_region_dashboard_total_accounts
      icon  = "groups"
      type  = "info"

      args = {
        "account_ids" = self.input.cost_by_region_dashboard_accounts.value
      }
    }

    card {
      width = 2
      query = query.cost_by_region_dashboard_total_regions
      icon  = "globe"
      type  = "info"

      args = {
        "account_ids" = self.input.cost_by_region_dashboard_accounts.value
      }
    }
  }

  container {
    # Cost Trend Graphs
    chart {
      title = "Monthly Cost Trend"
      type  = "column"
      width = 6
      query = query.cost_by_region_dashboard_monthly_cost

      args = {
        "account_ids" = self.input.cost_by_region_dashboard_accounts.value
      }

      legend {
        display = "none"
      }
    }

    chart {
      title = "Top 10 Regions"
      type  = "table"
      width = 6
      query = query.cost_by_region_dashboard_top_10_regions

      args = {
        "account_ids" = self.input.cost_by_region_dashboard_accounts.value
      }
    }
  }

  container {
    # Detailed Table
    table {
      title = "Region Costs"
      width = 12
      query = query.cost_by_region_dashboard_region_costs

      args = {
        "account_ids" = self.input.cost_by_region_dashboard_accounts.value
      }
    }
  }
}

# Query Definitions

query "cost_by_region_dashboard_total_cost" {
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

  param "account_ids" {}

  tags = {
    folder = "Hidden"
  }
}

query "cost_by_region_dashboard_total_accounts" {
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

query "cost_by_region_dashboard_total_regions" {
  sql = <<-EOQ
    select
      'Regions' as label,
      count(distinct coalesce(product_region_code, 'global')) as value
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

query "cost_by_region_dashboard_monthly_cost" {
  sql = <<-EOQ
    select
      strftime(date_trunc('month', line_item_usage_start_date), '%b %Y') as "Month",
      coalesce(product_region_code, 'global') as "Region",
      round(sum(line_item_unblended_cost), 2) as "Total Cost"
    from
      aws_cost_and_usage_report
    where
      ('all' in ($1) or line_item_usage_account_id in $1)
    group by
      date_trunc('month', line_item_usage_start_date),
      coalesce(product_region_code, 'global')
    order by
      date_trunc('month', line_item_usage_start_date),
      sum(line_item_unblended_cost) desc;
  EOQ

  param "account_ids" {}

  tags = {
    folder = "Hidden"
  }
}

query "cost_by_region_dashboard_top_10_regions" {
  sql = <<-EOQ
    select
      coalesce(product_region_code, 'global') as "Region",
      round(sum(line_item_unblended_cost), 2) as "Total Cost"
    from
      aws_cost_and_usage_report
    where
      ('all' in ($1) or line_item_usage_account_id in $1)
    group by
      coalesce(product_region_code, 'global')
    order by
      sum(line_item_unblended_cost) desc
    limit 10;
  EOQ

  param "account_ids" {}

  tags = {
    folder = "Hidden"
  }
}

query "cost_by_region_dashboard_region_costs" {
  sql = <<-EOQ
    select
      line_item_usage_account_id as "Account",
      coalesce(product_region_code, 'global') as "Region",
      round(sum(line_item_unblended_cost), 2) as "Total Cost"
    from
      aws_cost_and_usage_report
    where
      ('all' in ($1) or line_item_usage_account_id in $1)
    group by
      coalesce(product_region_code, 'global'),
      line_item_usage_account_id
    order by
      sum(line_item_unblended_cost) desc;
  EOQ

  param "account_ids" {}

  tags = {
    folder = "Hidden"
  }
}

query "cost_by_region_dashboard_accounts_input" {
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
