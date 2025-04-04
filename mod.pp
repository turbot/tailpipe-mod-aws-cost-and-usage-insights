mod "aws_cost_usage_report_detections" {
  # hub metadata
  title         = "AWS Cost and Usage Report Insights"
  description   = "Monitor and analyze costs across your AWS accounts using pre-built dashboards for AWS Cost and Usage Reports with Powerpipe and Tailpipe."
  color         = "#FF9900"
  documentation = file("./docs/index.md")
  # icon          = "/images/mods/turbot/aws-cost-usage-report.svg"
  categories = ["aws", "dashboard", "insights", "public cloud"]
  database   = var.database

  opengraph {
    title       = "Powerpipe Mod for AWS Cost and Usage Report Insights"
    description = "Monitor and analyze costs across your AWS accounts using pre-built dashboards for AWS Cost and Usage Reports with Powerpipe and Tailpipe."
    # image       = "/images/mods/turbot/aws-cost-usage-report-social-graphic.png"
  }

}