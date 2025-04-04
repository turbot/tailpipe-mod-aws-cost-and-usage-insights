dashboard "cost_and_usage_report" {
  title         = "Cost and Usage Report"
  documentation = file("./dashboards/docs/cost_and_usage_report.md")

  tags = {
    type    = "Report"
    service = "AWS/CostAndUsageReport"
  }

  container {
    # Input filters
    input "cost_and_usage_report_account_ids" {
      title = "Select accounts:"
      query = query.cost_and_usage_report_account_ids_input
      type  = "multiselect"
      width = 2
    }

    input "cost_and_usage_report_regions" {
      title = "Select regions:"
      query = query.cost_and_usage_report_regions_input
      type  = "multiselect"
      width = 2
    }

    input "cost_and_usage_report_services" {
      title = "Select services:"
      query = query.cost_and_usage_report_services_input
      type  = "multiselect"
      width = 2
    }
  }

  container {
    # Total count card
    card {
      query = query.cost_and_usage_report_total_records
      width = 2
      args = [
        self.input.cost_and_usage_report_account_ids.value,
        self.input.cost_and_usage_report_regions.value,
        self.input.cost_and_usage_report_services.value
      ]
    }
  }

  container {
    # Detailed table
    table {
      title = "Note: This table shows a maximum of 10,000 rows"
      query = query.cost_and_usage_report_table
      args = [
        self.input.cost_and_usage_report_account_ids.value,
        self.input.cost_and_usage_report_regions.value,
        self.input.cost_and_usage_report_services.value
      ]
    }
  }
}

# Main queries

query "cost_and_usage_report_total_records" {
  sql = <<-EOQ
    select
      count(*) as "Total Records"
    from
      aws_cost_and_usage_report
    where
      ('all' in ($1) or line_item_usage_account_id in ($1))
      and ('all' in ($2) or coalesce(product_region_code, 'global') in ($2))
      and ('all' in ($3) or product_service_code in ($3))
  EOQ
}

query "cost_and_usage_report_table" {
  sql = <<-EOQ
    select
      tp_timestamp,
      *
    from
      aws_cost_and_usage_report
    where
      ('all' in ($1) or line_item_usage_account_id in ($1))
      and ('all' in ($2) or coalesce(product_region_code, 'global') in ($2))
      and ('all' in ($3) or product_service_code in ($3))
    order by
      tp_timestamp desc
    limit 10000;
  EOQ
}

# Input queries

query "cost_and_usage_report_account_ids_input" {
  sql = <<-EOQ
    with account_ids as (
      select
        distinct(line_item_usage_account_id) as account_id
      from
        aws_cost_and_usage_report
      order by
        account_id
    )
    select
      'All' as label,
      'all' as value
    union all
    select
      account_id as label,
      account_id as value
    from
      account_ids;
  EOQ
}

query "cost_and_usage_report_regions_input" {
  sql = <<-EOQ
    with regions as (
      select
        distinct(coalesce(product_region_code, 'global')) as region
      from
        aws_cost_and_usage_report
      order by
        region
    )
    select
      'All' as label,
      'all' as value
    union all
    select
      region as label,
      region as value
    from
      regions;
  EOQ
}

query "cost_and_usage_report_services_input" {
  sql = <<-EOQ
    with services as (
      select
        distinct(product_service_code) as service
      from
        aws_cost_and_usage_report
      order by
        service
    )
    select
      'All' as label,
      'all' as value
    union all
    select
      service as label,
      service as value
    from
      services
  EOQ
}