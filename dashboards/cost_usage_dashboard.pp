dashboard "cost_usage_dashboard" {
  title         = "Cost and Usage Dashboard"
  documentation = file("./dashboards/docs/cost_usage_dashboard.md")

  tags = {
    type    = "Dashboard"
    service = "AWS/Billing"
  }

  container {
    # Multi-select Account Input
    input "accounts" {
      title       = "Select accounts:"
      description = "Choose one or more AWS accounts to analyze."
      type        = "multiselect"
      width       = 2
      query       = query.aws_accounts_input
    }
  }

  container {
    # Summary Metrics
    card {
      width = 2
      query = query.total_cost
      icon  = "attach_money"
      type  = "info"
      args  = {
        "line_item_usage_account_ids" = self.input.accounts.value
      }
    }
  }

  container {
    # Graphs
    chart {
      title = "Monthly Cost Trend"
      type  = "column"
      width = 6
      query = query.monthly_cost
      args  = {
        "line_item_usage_account_ids" = self.input.accounts.value
      }

      legend {
        display = "none"
      }
    }

    chart {
      title = "Daily Cost Trend"
      type  = "column"
      width = 6
      query = query.daily_cost
      args  = {
        "line_item_usage_account_ids" = self.input.accounts.value
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
      query = query.top_accounts
      args  = {
        "line_item_usage_account_ids" = self.input.accounts.value
      }
    }

    chart {
      title = "Top 10 Regions"
      type  = "table"
      width = 6
      query = query.top_regions
      args  = {
        "line_item_usage_account_ids" = self.input.accounts.value
      }
    }

    chart {
      title = "Top 10 Services"
      type  = "table"
      width = 6
      query = query.top_services
      args  = {
        "line_item_usage_account_ids" = self.input.accounts.value
      }
    }

    chart {
      title = "Top 10 Resources"

      type  = "table"
      width = 6
      query = query.top_resources
      args  = {
        "line_item_usage_account_ids" = self.input.accounts.value
      }
    }
  }
}

# Queries

query "total_cost" {
  title       = "Total Cost"
  description = "Total unblended cost for selected AWS accounts."
  sql = <<-EOQ
    select
      --format('{:.2f}', round(sum(line_item_unblended_cost), 2)) as "Total Cost"
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
}

query "monthly_cost" {
  title       = "Monthly Cost Trend"
  description = "Cost trend over the past 6 months."
  sql = <<-EOQ
    select
      strftime(date_trunc('month', line_item_usage_start_date), '%b %Y') as "Month",
      line_item_usage_account_id as "Account Id",
      round(sum(line_item_unblended_cost), 2) as "Total Cost"
    from
      aws_cost_and_usage_report
    where
      line_item_usage_start_date >= current_date - interval '6' month
      and ('all' in ($1) or line_item_usage_account_id in $1)
    group by
      date_trunc('month', line_item_usage_start_date),
      line_item_usage_account_id
    order by
      date_trunc('month', line_item_usage_start_date),
      line_item_usage_account_id;
  EOQ
  param "line_item_usage_account_ids" {}
}

query "daily_cost" {
  title       = "Daily Cost Trend"
  description = "Aggregated cost trend over the last 30 days across AWS accounts, grouped by account ID."
  sql = <<-EOQ
    select
      strftime(date_trunc('day', line_item_usage_start_date), '%d-%m-%Y') as "Date",
      line_item_usage_account_id as "Account",
      round(sum(line_item_unblended_cost), 2) as "Total Cost"
    from
      aws_cost_and_usage_report
    where
      line_item_usage_start_date >= current_date - interval '30' day
      and ('all' in ($1) or line_item_usage_account_id in $1)
    group by
      date_trunc('day', line_item_usage_start_date),
      line_item_usage_account_id
    order by
      date_trunc('day', line_item_usage_start_date),
      line_item_usage_account_id;
  EOQ

  param "line_item_usage_account_ids" {}
}

query "top_accounts" {
  title       = "Top 10 Accounts"
  description = "List of top 10 AWS accounts with the highest costs."
  sql = <<-EOQ
    select
      line_item_usage_account_id as "Account",
      --format('{:.2f}', round(sum(line_item_unblended_cost), 2)) as "Total Cost"
      round(sum(line_item_unblended_cost), 2) as "Total Cost"
    from
      aws_cost_and_usage_report
    where
      ('all' in ($1) or line_item_usage_account_id in $1)
    group by
      "Account"
    order by
      "Total Cost" desc
    limit 10;
  EOQ

  param "line_item_usage_account_ids" {}
}

query "top_regions" {
  title       = "Top 10 Regions"
  description = "List of top 10 AWS regions with the highest costs."
  sql = <<-EOQ
    select
      coalesce(product_region_code, 'global') as "Region",
      --format('{:.2f}', round(sum(line_item_unblended_cost), 2)) as "Total Cost"
      round(sum(line_item_unblended_cost), 2) as "Total Cost"
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
}

query "top_services" {
  title       = "Top 10 Services"
  description = "List of top 10 AWS services with the highest costs."
  sql = <<-EOQ
    select
      product_service_code as "Service",
      --format('{:.2f}', round(sum(line_item_unblended_cost), 2)) as "Total Cost"
      round(sum(line_item_unblended_cost), 2) as "Total Cost"
    from
      aws_cost_and_usage_report
    where
      ('all' in ($1) or line_item_usage_account_id in $1)
    group by 1
    order by 2 desc
    limit 10;
  EOQ
  param "line_item_usage_account_ids" {}
}

query "top_resources" {
  title       = "Top 10 Resources"
  description = "List of top 10 AWS resources with the highest costs."
  sql = <<-EOQ
    select
      line_item_resource_id as "Resource",
      line_item_usage_account_id as "Account",
      coalesce(product_region_code, 'global') as "Region",
      --format('{:.2f}', round(sum(line_item_unblended_cost), 2)) as "Total Cost"
      round(sum(line_item_unblended_cost), 2) as "Total Cost"
    from
      aws_cost_and_usage_report
    where
      ('all' in ($1)  or line_item_usage_account_id in $1)
      and line_item_resource_id is not null
    group by 1, 2, 3
    order by "Total Cost" desc
    limit 10;
  EOQ
  param "line_item_usage_account_ids" {}
}

query "aws_accounts_input" {
  title       = "AWS Account Selection"
  description = "Multi-select input to filter the dashboard by AWS accounts."
  sql = <<-EOQ
    select
      'All' as label,
      'all' as value
    union all
    select distinct line_item_usage_account_id as label,
      line_item_usage_account_id as value
    from aws_cost_and_usage_report;
  EOQ
}
