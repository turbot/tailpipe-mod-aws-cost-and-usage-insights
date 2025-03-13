dashboard "cost_by_resource_dashboard" {
  title = "Cost by Resource Dashboard"

  tags = {
    type    = "Dashboard"
    service = "AWS/CostExplorer"
  }

  input "account" {
    title       = "Select accounts:"
    description = "Select an AWS account to filter the dashboard."
    type        = "multiselect"
    query       = query.resource_aws_account_input
    width       = 2
  }

  input "service" {
    title       = "Select services:"
    description = "Select an AWS service to filter resources."
    type        = "multiselect"
    query       = query.resource_aws_service_input
    args        = {
      "line_item_usage_account_id" = self.input.account.value
    }
    width       = 2
  }

  container {
    # Summary Metrics
    card {
      width = 2
      query = query.total_resource_cost
      args  = {
        "line_item_usage_account_id" = self.input.account.value,
        "line_item_product_code"     = self.input.service.value
      }
    }

    card {
      width = 2
      query = query.resource_currency
      args  = {
        "line_item_usage_account_id" = self.input.account.value,
        "line_item_product_code"     = self.input.service.value
      }
    }
  }

  container {
    # Cost Trend and Top Resources
    chart {
      title = "Monthly Cost Trend"
      type  = "column"
      width = 6
      query = query.resource_cost_trend
      args  = {
        "line_item_usage_account_id" = self.input.account.value,
        "line_item_product_code"     = self.input.service.value
      }
    }

    chart {
      title = "Top 10 Resources"
      type  = "table"
      width = 6
      query = query.top_resources_by_cost
      args  = {
        "line_item_usage_account_id" = self.input.account.value,
        "line_item_product_code"     = self.input.service.value
      }
    }
  }

  container {
    # Detailed Table
    table {
      title = "Resource Costs"
      width = 12
      query = query.resource_cost_breakdown
      args  = {
        "line_item_usage_account_id" = self.input.account.value,
        "line_item_product_code"     = self.input.service.value
      }
    }
  }
}

# Query Definitions

query "total_resource_cost" {
  title       = "Total Resource Cost"
  description = "Total cost for all resources in the selected AWS account and service."
  sql = <<-EOQ
    select 
      round(sum(line_item_unblended_cost), 2) as "Total Cost"
    from 
      aws_cost_and_usage_report
    where 
      ('all' in ($1) or line_item_usage_account_id in $1)
      and ('all' in ($2) or line_item_product_code in $2);
  EOQ

  param "line_item_usage_account_id" {}
  param "line_item_product_code" {}
}

query "resource_currency" {
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

  param "line_item_usage_account_id" {}
  param "line_item_product_code" {}
}

query "resource_cost_trend" {
  title       = "Monthly Cost Trend"
  description = "Cost trend over the last 6 months for selected AWS account and service."
  sql = <<-EOQ
    select 
      strftime(date_trunc('month', line_item_usage_start_date), '%b %Y') as "Month",
      round(sum(line_item_unblended_cost), 2) as "Total Cost"
    from 
      aws_cost_and_usage_report
    where 
      ('all' in ($1) or line_item_usage_account_id in $1)
      and ('all' in ($2) or line_item_product_code in $2)
      and line_item_usage_start_date >= current_date - interval '6' month
    group by 
      date_trunc('month', line_item_usage_start_date)
    order by 
      date_trunc('month', line_item_usage_start_date);
  EOQ

  param "line_item_usage_account_id" {}
  param "line_item_product_code" {}
}

query "top_resources_by_cost" {
  title       = "Top 10 Resources"
  description = "Top 10 most expensive resources for selected AWS account and service."
  sql = <<-EOQ
    select 
      line_item_resource_id as "Resource",
      line_item_usage_account_id as "Account",
      coalesce(product_region_code, 'global') as "Region",
      round(sum(line_item_unblended_cost), 2) as "Total Cost"
    from 
      aws_cost_and_usage_report
    where 
      ('all' in ($1) or line_item_usage_account_id in $1)
      and ('all' in ($2) or line_item_product_code in $2)
      and line_item_resource_id is not null
    group by 
      line_item_resource_id,
      line_item_usage_account_id,
      "Region"
    order by 
      sum(line_item_unblended_cost) desc
    limit 10;
  EOQ

  param "line_item_usage_account_id" {}
  param "line_item_product_code" {}
}

query "resource_cost_breakdown" {
  title       = "Resource Cost Breakdown"
  description = "Detailed breakdown of costs for each resource, including service, region, account, and cost."
  sql = <<-EOQ
    select 
      case 
        when line_item_resource_id like 'arn:aws:%' then line_item_resource_id
        else 
          format(
            'arn:aws:{}:{}:{}:{}',
            lower(regexp_replace(line_item_product_code, '^(AWS|Amazon)', '', 'i')),
            coalesce(nullif(product_region_code, ''), 'global'),
            line_item_usage_account_id,
            line_item_resource_id
          )
      end as "Resource",
      line_item_product_code as "Service",
      line_item_usage_account_id as "Account",
      coalesce(product_region_code, 'global') as "Region",
      round(sum(line_item_unblended_cost), 2) as "Total Cost"
    from 
      aws_cost_and_usage_report
    where 
      ('all' in ($1) or line_item_usage_account_id in $1)
      and ('all' in ($2) or line_item_product_code in $2)
      and line_item_resource_id is not null
    group by 
      case 
        when line_item_resource_id like 'arn:aws:%' then line_item_resource_id
        else 
          format(
            'arn:aws:{}:{}:{}:{}',
            lower(regexp_replace(line_item_product_code, '^(AWS|Amazon)', '', 'i')),
            coalesce(nullif(product_region_code, ''), 'global'),
            line_item_usage_account_id,
            line_item_resource_id
          )
      end,
      line_item_product_code,
      coalesce(product_region_code, 'global'),
      line_item_usage_account_id
    order by 
      sum(line_item_unblended_cost) desc;
  EOQ

  param "line_item_usage_account_id" {}
  param "line_item_product_code" {}
}

query "resource_aws_service_input" {
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

query "resource_aws_account_input" {
  title       = "AWS Account Selection"
  description = "Select an AWS account for filtering dashboard data."
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
}
