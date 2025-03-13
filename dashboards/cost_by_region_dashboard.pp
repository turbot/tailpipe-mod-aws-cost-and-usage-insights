dashboard "cost_by_region_dashboard" {
  title = "Cost by Region Dashboard"

  tags = {
    type    = "Dashboard"
    service = "AWS/CostExplorer"
  }

  container {
    # Multi-select Account Input
    input "region_accounts_input" {
      title       = "Select accounts:"
      description = "Choose one or more AWS accounts to analyze."
      type        = "multiselect"
      width       = 2
      query       = query.region_accounts_input
    }
  }

  container {
    # Summary Cards
    card {
      width = 2
      query = query.region_total_cost
       args  = {
        "line_item_usage_account_ids" = self.input.region_accounts_input.value
      }
    }

    card {
      width = 2
      query = query.region_currency
       args  = {
        "line_item_usage_account_ids" = self.input.region_accounts_input.value
      }
    }
  }

  container {
    # Cost Trend Graphs
    chart {
      title = "Monthly Region Cost Trend"
      #type  = "bar"
      width = 6
      query = query.region_monthly_cost
       args  = {
        "line_item_usage_account_ids" = self.input.region_accounts_input.value
      }
      legend {
        display  = "none"
        position = "bottom"
      }
    }

    chart {
      title = "Top 10 Regions by Cost"
      type  = "table"
      width = 6
      query = query.region_top_10
       args  = {
        "line_item_usage_account_ids" = self.input.region_accounts_input.value
      }
    }
  }

  container {
    # Detailed Tables
    table {
      title = "Region Cost Details"
      width = 12
      query = query.region_cost_details
       args  = {
        "line_item_usage_account_ids" = self.input.region_accounts_input.value
      }
    }
  }
}

# Query Definitions

query "region_total_cost" {
  title       = "Total Region Cost"
  description = "Total unblended cost across all AWS regions."
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


query "region_currency" {
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

query "region_monthly_cost" {
  title       = "Monthly Region Cost Trend"
  description = "Aggregated cost trend over the last 6 months across AWS regions."
  sql = <<-EOQ
    select 
      strftime(date_trunc('month', line_item_usage_start_date), '%b %Y') as "Month",
      product_region_code,
      round(sum(line_item_unblended_cost), 2) as "Total Cost"
    from 
      aws_cost_and_usage_report
    where 
      line_item_usage_start_date >= current_date - interval '6' month
      and ('all' in ($1) or line_item_usage_account_id in $1)
    group by 
      date_trunc('month', line_item_usage_start_date),
      product_region_code
    order by 
      date_trunc('month', line_item_usage_start_date);
  EOQ

  param "line_item_usage_account_ids" {}
}

query "region_top_10" {
  title       = "Top 10 Regions by Cost"
  description = "List of top 10 AWS regions with the highest costs."
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

  param "line_item_usage_account_ids" {}
}

query "region_cost_details" {
  title       = "Region Cost Details"
  description = "Detailed cost breakdown per AWS region."
  sql = <<-EOQ
    select 
      line_item_usage_account_id as "Account",
      coalesce(product_region_code, 'global') as "Region",
      round(sum(line_item_unblended_cost), 2) as "Cost"
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

  param "line_item_usage_account_ids" {}
}


query "region_accounts_input" {
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
