dashboard "cost_usage_dashboard" {
  title         = "AWS Cost and Usage Dashboard"
  documentation = file("./dashboards/docs/cost_usage_dashboard.md")

  tags = {
    type    = "dashboard"
    service = "aws/costandusage"
  }

  input "account" {
    title       = "AWS Account"
    description = "Select an AWS account to filter the dashboard"
    type        = "select"
    query       = query.aws_account_input
  }

  container {
    # Summary Metrics
    card {
      width = 3
      query = query.currency
      args  = {
        "line_item_usage_account_id" = self.input.account.value
      }
    }

    card {
      width = 3
      query = query.total_cost
      args  = {
        "line_item_usage_account_id" = self.input.account.value
      }
    }

    card {
      width = 3
      query = query.total_accounts
    }

    card {
      width = 3
      query = query.total_services
      args  = {
        "line_item_usage_account_id" = self.input.account.value
      }
    }
  }

  container {
    chart {
      title = "Cost by Service"
      type  = "column"
      width = 6
      query = query.cost_by_service
      args  = {
        "line_item_usage_account_id" = self.input.account.value
      }
    }

    chart {
      title = "Cost by Region"
      type  = "column"
      width = 6
      query = query.cost_by_region
      args  = {
        "line_item_usage_account_id" = self.input.account.value
      }
    }

    chart {
      title = "Cost by Resource"
      type  = "pie"
      width = 6
      query = query.cost_by_resources
      args  = {
        "line_item_usage_account_id" = self.input.account.value
      }
    }

    chart {
      title = "Cost by Usage Type"
      type  = "pie"
      width = 6
      query = query.cost_by_usage_type
      args  = {
        "line_item_usage_account_id" = self.input.account.value
      }
    }

    chart {
      title = "Top 10 High-Cost Services"
      type  = "table"
      width = 6
      query = query.top_services
      args  = {
        "line_item_usage_account_id" = self.input.account.value
      }
    }

    card {
      title = "AWS Cost Anomaly Detection"
      type  = "table"
      width = 6
      query = query.cost_anomaly_detection
      args  = {
        "line_item_usage_account_id" = self.input.account.value
      }
    }

    chart {
      title = "Cost Over Time (Last 30 Days)"
      type  = "line"
      width = 12
      query = query.cost_over_time
      args  = {
        "line_item_usage_account_id" = self.input.account.value
      }
    }
  }
}

# Query Definitions

query "currency" {
  title       = "Currency"
  description = "Shows the currency used for cost calculations"
  sql         = <<-EOQ
    select distinct line_item_currency_code as "Currency"
    from 
      aws_cost_and_usage_report
    where
      line_item_usage_account_id = $1;
  EOQ

  param "line_item_usage_account_id" {}

  tags = {
    folder = "Account"
  }
}

query "total_cost" {
  title       = "Total Cost"
  description = "Total unblended cost for the selected AWS account"
  sql         = <<-EOQ
    select 
      round(sum(line_item_unblended_cost), 2) as "Total Cost"
    from 
      aws_cost_and_usage_report
    where
      line_item_usage_account_id = $1;
  EOQ

  param "line_item_usage_account_id" {}

  tags = {
    folder = "Account"
  }
}

query "total_accounts" {
  title       = "Total AWS Accounts"
  description = "Total number of unique AWS accounts in the cost and usage report"
  sql         = <<-EOQ
    select 
      count(distinct line_item_usage_account_id) as "Total Accounts"
    from 
      aws_cost_and_usage_report;
  EOQ

  tags = {
    folder = "Account"
  }
}

query "total_services" {
  title       = "Total AWS Services"
  description = "Total number of unique AWS services used across accounts"
  sql         = <<-EOQ
    select 
      count(distinct line_item_product_code) as "Total Services"
    from 
      aws_cost_and_usage_report
    where
      line_item_usage_account_id = $1;
  EOQ

  param "line_item_usage_account_id" {}

  tags = {
    folder = "Account"
  }
}

query "cost_by_service" {
  title       = "Cost by Service"
  description = "Distribution of costs across different AWS services for the selected account"
  sql         = <<-EOQ
    select 
      line_item_product_code as "service",
      sum(line_item_unblended_cost) as "total cost"
    from 
      aws_cost_and_usage_report
    where
      line_item_usage_account_id = $1
    group by 
      line_item_product_code
    order by 
      sum(line_item_unblended_cost) desc;
  EOQ

  param "line_item_usage_account_id" {}

  tags = {
    folder = "Account"
  }
}

query "cost_by_region" {
  title       = "Cost by Region"
  description = "Distribution of costs across different AWS regions for the selected account"
  sql         = <<-EOQ
    select 
      (product ->> 'region') as "aws region",
      sum(line_item_unblended_cost) as "total cost"
    from 
      aws_cost_and_usage_report
    where
      line_item_usage_account_id = $1
    group by 
      (product ->> 'region')
    order by 
      sum(line_item_unblended_cost) desc;
  EOQ

  param "line_item_usage_account_id" {}

  tags = {
    folder = "Account"
  }
}

query "cost_anomaly_detection" {
  title       = "Cost Anomaly Detection"
  description = "Detects cost anomalies by comparing daily costs against 7-day moving average"
  sql         = <<-EOQ
    select 
      strftime(date_trunc('day', line_item_usage_start_date), '%d %b %Y') as "date",
      sum(line_item_unblended_cost) as "daily cost", 
      avg(sum(line_item_unblended_cost)) over (order by date_trunc('day', line_item_usage_start_date) rows between 6 preceding and current row) as "7-day avg cost",
      sum(line_item_unblended_cost) - avg(sum(line_item_unblended_cost)) over (order by date_trunc('day', line_item_usage_start_date) rows between 6 preceding and current row) as "cost anomaly"
    from 
      aws_cost_and_usage_report
    where 
      line_item_usage_start_date >= current_date - interval '30' day
      and line_item_usage_account_id = $1
    group by 
      date_trunc('day', line_item_usage_start_date)
    order by 
      date_trunc('day', line_item_usage_start_date) asc;
  EOQ

  param "line_item_usage_account_id" {}

  tags = {
    folder = "optimization"
  }
}

query "cost_by_usage_type" {
  title       = "Cost by Usage Type"
  description = "Distribution of costs across different AWS usage types for the selected account"
  sql         = <<-EOQ
    select 
      line_item_usage_type as "usage type",
      sum(line_item_unblended_cost) as "Total Cost"
    from 
      aws_cost_and_usage_report
    where
      line_item_usage_account_id = $1
    group by 
      line_item_usage_type
    order by 
      sum(line_item_unblended_cost) desc;
  EOQ

  param "line_item_usage_account_id" {}

  tags = {
    folder = "Account"
  }
}

query "top_services" {
  title       = "Top 10 High-Cost Services"
  description = "List of top 10 AWS services with highest costs across all accounts"
  sql         = <<-EOQ
    select 
      product_service_code as "service",
      sum(line_item_unblended_cost) as "total cost"
    from 
      aws_cost_and_usage_report
    where
      line_item_usage_account_id = $1
    group by 
      product_service_code
    order by 
      sum(line_item_unblended_cost) desc
    limit 10;
  EOQ

  param "line_item_usage_account_id" {}

  tags = {
    folder = "Account"
  }
}

query "cost_by_resources" {
  title       = "Cost by Resources"
  description = "Distribution of costs across different AWS resources for the selected account"
  sql         = <<-EOQ
    select 
      line_item_resource_id as "resource",
      sum(line_item_unblended_cost) as "Total Cost"
    from 
      aws_cost_and_usage_report
    where 
      line_item_resource_id is not null
      and line_item_usage_account_id = $1
    group by 
      line_item_resource_id
    order by 
      sum(line_item_unblended_cost) desc
  EOQ

  param "line_item_usage_account_id" {}

  tags = {
    folder = "Account"
  }
}

query "cost_over_time" {
  title       = "Cost Over Time"
  description = "Daily cost trend over the last 30 days"
  sql         = <<-EOQ
    select 
      strftime(date_trunc('day', line_item_usage_start_date), '%d %b %Y') as "date",
      sum(line_item_unblended_cost) as "total cost"
    from 
      aws_cost_and_usage_report
    where 
      line_item_usage_start_date >= current_date - interval '30' day
      and line_item_usage_account_id = $1
    group by 
      date_trunc('day', line_item_usage_start_date)
    order by 
      date_trunc('day', line_item_usage_start_date) asc;
  EOQ

  param "line_item_usage_account_id" {}

  tags = {
    folder = "Account"
  }
}

# Query Input
query "aws_account_input" {
  title       = "AWS Account Selection"
  description = "Input control to select an AWS account for filtering dashboard data"
  sql         = <<-EOQ
    select 
      distinct line_item_usage_account_id as label,
      line_item_usage_account_id as value
    from 
      aws_cost_and_usage_report;
  EOQ
}