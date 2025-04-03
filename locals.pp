// Benchmarks and controls for specific services should override the "service" tag
locals {
  aws_cost_usage_report_thrifty_common_tags = {
    category = "Thrifty"
    plugin   = "aws"
    service  = "AWS/CostExplorer"
  }
}
