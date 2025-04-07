# AWS Cost and Usage Insights Mod

[Tailpipe](https://tailpipe.io) is an open-source CLI tool that allows you to collect logs and query them with SQL.

[AWS](https://aws.amazon.com/) provides on-demand cloud computing platforms and APIs to authenticated customers on a metered pay-as-you-go basis.

The [AWS Cost and Usage Insights Mod](https://hub.powerpipe.io/mods/turbot/tailpipe-mod-aws-cost-and-usage-insights) contains pre-built dashboards which can be used to monitor and analyze costs across your AWS accounts using [Cost and Usage Reports](https://docs.aws.amazon.com/cur/latest/userguide/table-dictionary-cur2.html).

<img src="https://raw.githubusercontent.com/turbot/tailpipe-mod-aws-cost-and-usage-insights/main/docs/images/aws_cost_and_usage_overview_dashboard.png" width="50%" type="thumbnail"/>
<img src="https://raw.githubusercontent.com/turbot/tailpipe-mod-aws-cost-and-usage-insights/main/docs/images/aws_cost_and_usage_cost_by_service_dashboard.png" width="50%" type="thumbnail"/>

## Documentation

- **[Dashboards →](https://hub.powerpipe.io/mods/turbot/tailpipe-mod-aws-cost-and-usage-insights/dashboards)**

## Getting Started

Install Powerpipe from the [downloads](https://powerpipe.io/downloads) page:

```sh
# MacOS
brew install turbot/tap/powerpipe
```

```sh
# Linux or Windows (WSL)
sudo /bin/sh -c "$(curl -fsSL https://powerpipe.io/install/powerpipe.sh)"
```

This mod requires AWS Cost and Usage Reports to be collected using [Tailpipe](https://tailpipe.io) with the [AWS plugin](https://hub.tailpipe.io/plugins/turbot/aws):

- [Get started with the AWS plugin for Tailpipe →](https://hub.tailpipe.io/plugins/turbot/aws#getting-started)

Install the mod:

```sh
mkdir dashboards
cd dashboards
powerpipe mod install github.com/turbot/tailpipe-mod-aws-cost-and-usage-insights
```

### Browsing Dashboards

Start the dashboard server:

```sh
powerpipe server
```

Browse and view your dashboards at **http://localhost:9033**.
