mod "aws_cost_and_usage_insights" {
  # hub metadata
  title         = "AWS Cost and Usage Insights"
  description   = "Monitor and analyze costs across your AWS accounts using pre-built dashboards for AWS Cost and Usage Reports with Powerpipe and Tailpipe."
  color         = "#FF9900"
  documentation = file("./docs/index.md")
  # icon          = "/images/mods/turbot/aws-cost-and-usage-insights.svg"
  categories = ["aws", "cost", "dashboard", "public cloud"]
  database   = var.database

  opengraph {
    title       = "Powerpipe Mod for AWS Cost and Usage Insights"
    description = "Monitor and analyze costs across your AWS accounts using pre-built dashboards for AWS Cost and Usage Reports with Powerpipe and Tailpipe."
    # image       = "/images/mods/turbot/aws-cost-and-usage-insights-social-graphic.png"
  }

}
