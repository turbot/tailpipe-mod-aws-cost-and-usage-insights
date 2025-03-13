dashboard "cost_by_account_dashboard" {
  title = "Cost by Account Dashboard"

  tags = {
    type    = "Dashboard"
    service = "AWS/CostExplorer"
  }

 container {
    # Multi-select Account Input
    input "accounts_input" {
      title       = "Select accounts:"
      description = "Choose one or more AWS accounts to analyze."
      type        = "multiselect"
      width       = 2
      query       = query.accounts_input
    }
  }

  container {
    # Summary Cards
    card {
      width = 2
      query = query.account_total_cost
      args  = {
        "line_item_usage_account_ids" = self.input.accounts_input.value
      }
    }

    card {
      width = 2
      query = query.account_currency
      args  = {
        "line_item_usage_account_ids" = self.input.accounts_input.value
      }
    }
  }

  container {
    # Cost Trend Charts
    chart {
      title = "Monthly Cost Trend"
      type  = "column"
      width = 6
      query = query.monthly_cost_trend
      args  = {
        "line_item_usage_account_ids" = self.input.accounts_input.value
      }

      series "Total Cost" {
        title = "Account Costs"
      }
    }

    chart {
      title = "Top 10 Accounts"
      type  = "table"
      width = 6
      query = query.account_top_10
      args  = {
        "line_item_usage_account_ids" = self.input.accounts_input.value
      }

    }
  }

  container {
    # Detailed Table
    table {
      title = "Account Costs"
      width = 12
      query = query.account_cost_details
      args  = {
        "line_item_usage_account_ids" = self.input.accounts_input.value
      }
    }
  }
}

# Query Definitions

query "account_total_cost" {
  title       = "Total Cost"
  description = "Aggregated total cost across all AWS accounts."
  sql = <<-EOQ
    select 
      round(sum(line_item_unblended_cost), 2) as "Total Cost"
    from 
      aws_cost_and_usage_report
    where 
      ('all' in ($1) or line_item_usage_account_id in $1);
  EOQ

  param "line_item_usage_account_ids" {}
}

query "account_currency" {
  title       = "Currency"
  description = "Currency used for cost calculations in AWS accounts."
  sql = <<-EOQ
    select 
      distinct line_item_currency_code as "Currency"
    from 
      aws_cost_and_usage_report
    where 
      ('all' in ($1) or line_item_usage_account_id in $1)
    limit 1;
  EOQ

  param "line_item_usage_account_ids" {}
}

query "monthly_cost_trend" {
  title       = "Monthly Cost Trend"
  description = "Aggregated cost trend over the last 6 months across AWS accounts, grouped by account ID."
  sql = <<-EOQ
    select 
      strftime(date_trunc('month', line_item_usage_start_date), '%b %Y') as "Month",
      line_item_usage_account_id as "Account",
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

query "account_top_10" {
  title       = "Top 10 Accounts"
  description = "List of top 10 AWS accounts with the highest costs."
  sql = <<-EOQ
    select 
      line_item_usage_account_id as "Account",
      round(sum(line_item_unblended_cost), 2) as "Total Cost"
    from 
      aws_cost_and_usage_report
    where
      ('all' in ($1) or line_item_usage_account_id in $1)
    group by 
      line_item_usage_account_id
    order by 
      sum(line_item_unblended_cost) desc
    limit 10;
  EOQ

  param "line_item_usage_account_ids" {}
}

query "account_cost_details" {
  title       = "Account Cost Details"
  description = "Detailed cost breakdown per AWS account, including number of services and regions used."
  sql = <<-EOQ
    select 
      line_item_usage_account_id as "Account",
      round(sum(line_item_unblended_cost), 2) as "Total Cost",
    from 
      aws_cost_and_usage_report
    where
      ('all' in ($1) or line_item_usage_account_id in $1)
    group by 
      line_item_usage_account_id
    order by 
      sum(line_item_unblended_cost) desc;
  EOQ

  param "line_item_usage_account_ids" {}
}

query "accounts_input" {
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
