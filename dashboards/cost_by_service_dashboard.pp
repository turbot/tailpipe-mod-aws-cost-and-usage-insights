dashboard "cost_by_service_dashboard" {
  title = "Cost by Service Dashboard"

  tags = {
    type    = "Dashboard"
    service = "AWS/CostExplorer"
  }

  input "account_input" {
    title       = "Select account:"
    description = "Choose a single AWS account to analyze"
    type        = "multiselect"
    width       = 2
    query       = query.service_accounts_input
  }

  input "service_input" {
    title       = "Select service:"
    description = "Select an AWS service to filter resources."
    type        = "multiselect"
    query       = query.service_input
    args        = {
      "line_item_usage_account_id" = self.input.account_input.value
    }
    width       = 2
  }

  container {
    # Summary Cards
    card {
      width = 2
      query = query.service_total_cost
      args = {
        "account_id" = self.input.account_input.value
        "line_item_product_code"     = self.input.service_input.value
      }
    }

    card {
      width = 2
      query = query.service_currency
      args = {
        "account_id" = self.input.account_input.value
        "line_item_product_code"     = self.input.service_input.value
      }
    }
  }

  container {
    # Cost Trend Graphs
    chart {
      title = "Monthly Service Cost Trend"
      type  = "bar"
      width = 6
      query = query.service_monthly_cost
      args = {
        "account_id" = self.input.account_input.value
        "line_item_product_code"     = self.input.service_input.value
      }

      legend {
        display  = "none"
        position = "bottom"
      }
    }

    chart {
      title = "Top 10 Services by Cost"
      type  = "donut"
      width = 6
      query = query.service_top_10
      args = {
        "account_id" = self.input.account_input.value
        "line_item_product_code"     = self.input.service_input.value
      }
    }
  }

  container {
    # Detailed Tables
    table {
      title = "Service Cost Details"
      width = 12
      query = query.service_cost_details
      args = {
        "account_id" = self.input.account_input.value
        "line_item_product_code"     = self.input.service_input.value
      }
    }
  }
}

# Query Definitions

query "service_total_cost" {
  title       = "Total Service Cost"
  description = "Total unblended cost for the selected AWS account."
  sql = <<-EOQ
    select 
      round(sum(line_item_unblended_cost), 2) as "Total Cost"
    from 
      aws_cost_and_usage_report
    where 
      ('all' in ($1) or line_item_usage_account_id in $1)
      and ('all' in ($2) or line_item_product_code in $2);
  EOQ

  param "account_id" {}
  param "line_item_product_code" {}
}

query "service_currency" {
  title       = "Currency"
  description = "Currency used for cost calculations in the selected AWS account."
  sql = <<-EOQ
    select 
      distinct line_item_currency_code as "Currency"
    from 
      aws_cost_and_usage_report
    where 
      ('all' in ($1) or line_item_usage_account_id in $1)
      and ('all' in ($2) or line_item_product_code in $2)
    limit 1;
  EOQ

  param "account_id" {}
  param "line_item_product_code" {}
}

query "service_monthly_cost" {
  title       = "Monthly Service Cost Trend"
  description = "Aggregated cost trend over the last 6 months for the selected AWS account."
  sql = <<-EOQ
    select 
      strftime(date_trunc('month', line_item_usage_start_date), '%b %Y') as "Month",
      line_item_product_code,
      round(sum(line_item_unblended_cost), 2) as "Total Cost"
    from 
      aws_cost_and_usage_report
    where 
      ('all' in ($1) or line_item_usage_account_id in $1)
      and ('all' in ($2) or line_item_product_code in $2)
      and line_item_usage_start_date >= current_date - interval '6' month
    group by 
      date_trunc('month', line_item_usage_start_date),
      line_item_product_code
    order by 
      date_trunc('month', line_item_usage_start_date);
  EOQ

  param "account_id" {}
  param "line_item_product_code" {}
}

query "service_top_10" {
  title       = "Top 10 Services by Cost"
  description = "List of top 10 AWS services with the highest costs for the selected account."
  sql = <<-EOQ
    select 
      line_item_product_code as "Service",
      round(sum(line_item_unblended_cost), 2) as "Total Cost"
    from 
      aws_cost_and_usage_report
    where 
      ('all' in ($1) or line_item_usage_account_id in $1)
      and ('all' in ($2) or line_item_product_code in $2)
    group by 
      line_item_product_code
    order by 
      sum(line_item_unblended_cost) desc
    limit 10;
  EOQ

  param "account_id" {}
  param "line_item_product_code" {}
}

query "service_cost_details" {
  title       = "Service Cost Details"
  description = "Detailed cost breakdown per AWS service, including region and account."
  sql = <<-EOQ
    select 
      line_item_product_code as "Service",
      line_item_usage_account_id as "Account",
      round(sum(line_item_unblended_cost), 2) as "Total Cost"
    from 
      aws_cost_and_usage_report
    where 
      ('all' in ($1) or line_item_usage_account_id in $1)
      and ('all' in ($2) or line_item_product_code in $2)
    group by 
      line_item_product_code,
      line_item_usage_account_id
    order by 
      sum(line_item_unblended_cost) desc;
  EOQ

  param "account_id" {}
  param "line_item_product_code" {}
}

query "service_accounts_input" {
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

query "service_input" {
  title       = "AWS Service Selection"
  description = "Select an AWS service for filtering resources."
  sql = <<-EOQ
    select 
      'All' as label,
      'all' as value
    union
    select 
      distinct line_item_product_code as label,
      line_item_product_code as value
    from 
      aws_cost_and_usage_report
    where 
      ('all' in ($1) or line_item_usage_account_id in $1)
    order by 
      label;
  EOQ

  param "line_item_usage_account_id" {}
}