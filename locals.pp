// Benchmarks and controls for specific services should override the "service" tag
locals {
  aws_cost_and_usage_insights_common_tags = {
    category = "Insights"
    plugin   = "aws"
    service  = "AWS/CostAndUsageReport"
  }
}
