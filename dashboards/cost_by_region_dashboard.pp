dashboard "cost_by_region_dashboard" {
  title         = "Cost by Region Dashboard"
  documentation = file("./dashboards/docs/cost_by_region_dashboard.md")

  tags = {
    type    = "Dashboard"
    service = "AWS/CostAndUsageReport"
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

    # Multi-select Region Input
    input "regions_input" {
      title       = "Select regions:"
      description = "Choose one or more AWS regions to analyze."
      type        = "multiselect"
      width       = 2
      query       = query.regions_input
      args = {
        "line_item_usage_account_ids" = self.input.region_accounts_input.value
      }
    }
  }

  container {
    # Combined card showing Total Cost with Currency
    card {
      width = 4
      query = query.region_total_cost_with_currency
      args = {
        "line_item_usage_account_ids" = self.input.region_accounts_input.value,
        "product_region_codes"        = self.input.regions_input.value
      }
    }
  }

  container {
    # Cost Trend Graphs
    chart {
      title = "Monthly Cost Trend"
      #type  = "bar"
      width = 6
      query = query.region_monthly_cost
      args = {
        "line_item_usage_account_ids" = self.input.region_accounts_input.value,
        "product_region_codes"        = self.input.regions_input.value
      }
      legend {
        display = "none"
      }
    }

    chart {
      title = "Top 10 Regions"
      type  = "table"
      width = 6
      query = query.region_top_10
      args = {
        "line_item_usage_account_ids" = self.input.region_accounts_input.value,
        "product_region_codes"        = self.input.regions_input.value
      }
    }
  }

  container {
    # Detailed Table
    table {
      title = "Region Costs by Account"
      width = 12
      query = query.region_cost_details
      args = {
        "line_item_usage_account_ids" = self.input.region_accounts_input.value,
        "product_region_codes"        = self.input.regions_input.value
      }
    }
  }
}

# Query Definitions

query "region_total_cost_with_currency" {
  title       = "Total Cost"
  description = "Total unblended cost across all AWS regions with currency."
  sql         = <<-EOQ
    select 
      'Total Cost' as metric,
      concat(round(sum(line_item_unblended_cost), 2), ' ', line_item_currency_code) as value
    from 
      aws_cost_and_usage_report
    where 
      ('all' in ($1) or line_item_usage_account_id in $1)
      and ('all' in ($2) or coalesce(product_region_code, 'global') in $2)
    group by
      line_item_currency_code
    limit 1;
  EOQ

  param "line_item_usage_account_ids" {}
  param "product_region_codes" {}
}

query "region_monthly_cost" {
  title       = "Monthly Cost Trend"
  description = "Aggregated cost trend over the last 6 months across AWS regions."
  sql         = <<-EOQ
    select 
      strftime(date_trunc('month', line_item_usage_start_date), '%b %Y') as "Month",
      coalesce(product_region_code, 'global') as "Region",
      round(sum(line_item_unblended_cost), 2) as "Total Cost"
    from 
      aws_cost_and_usage_report
    where 
      line_item_usage_start_date >= current_date - interval '6' month
      and ('all' in ($1) or line_item_usage_account_id in $1)
      and ('all' in ($2) or coalesce(product_region_code, 'global') in $2)
    group by 
      date_trunc('month', line_item_usage_start_date),
      coalesce(product_region_code, 'global')
    order by 
      date_trunc('month', line_item_usage_start_date);
  EOQ

  param "line_item_usage_account_ids" {}
  param "product_region_codes" {}
}

query "region_top_10" {
  title       = "Top 10 Regions"
  description = "List of top 10 AWS regions with the highest costs."
  sql         = <<-EOQ
    select 
      coalesce(product_region_code, 'global') as "Region",
      round(sum(line_item_unblended_cost), 2) as "Total Cost"
    from 
      aws_cost_and_usage_report
    where
      ('all' in ($1) or line_item_usage_account_id in $1)
      and ('all' in ($2) or coalesce(product_region_code, 'global') in $2)
    group by 
      coalesce(product_region_code, 'global')
    order by 
      sum(line_item_unblended_cost) desc
    limit 10;
  EOQ

  param "line_item_usage_account_ids" {}
  param "product_region_codes" {}
}

query "region_cost_details" {
  title       = "Region Cost Details"
  description = "Detailed cost breakdown per AWS region."
  sql         = <<-EOQ
    select 
      line_item_usage_account_id as "Account",
      coalesce(product_region_code, 'global') as "Region",
      round(sum(line_item_unblended_cost), 2) as "Cost"
    from 
      aws_cost_and_usage_report
    where
      ('all' in ($1) or line_item_usage_account_id in $1)
      and ('all' in ($2) or coalesce(product_region_code, 'global') in $2)
    group by 
      coalesce(product_region_code, 'global'),
      line_item_usage_account_id
    order by 
      sum(line_item_unblended_cost) desc;
  EOQ

  param "line_item_usage_account_ids" {}
  param "product_region_codes" {}
}

query "region_accounts_input" {
  title       = "AWS Account Selection"
  description = "Multi-select input to filter the dashboard by AWS accounts."
  sql         = <<-EOQ
    select
      'All' as label,
      'all' as value
    union all
    select distinct line_item_usage_account_id as label,
      line_item_usage_account_id as value
    from aws_cost_and_usage_report;
  EOQ
}

query "regions_input" {
  title       = "AWS Region Selection"
  description = "Multi-select input to filter the dashboard by AWS regions."
  sql         = <<-EOQ
    select
      'All' as label,
      'all' as value
    union all
    select 
      coalesce(product_region_code, 'global') as label,
      coalesce(product_region_code, 'global') as value
    from 
      aws_cost_and_usage_report
    where 
      ('all' in ($1) or line_item_usage_account_id in $1)
    group by 
      coalesce(product_region_code, 'global')
    order by 
      label;
  EOQ

  param "line_item_usage_account_ids" {}
}