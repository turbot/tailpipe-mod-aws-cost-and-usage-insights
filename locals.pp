// Benchmarks and controls for specific services should override the "service" tag
locals {
  aws_cloudtrail_log_detections_common_tags = {
    category = "Thrifty"
    plugin   = "aws"
    service  = "AWS/CostExplorer"
  }
}
