resource "aws_sns_topic" "alarms" {
  name = "${var.project}-alarms"
}

resource "aws_sns_topic_subscription" "email" {
  topic_arn = aws_sns_topic.alarms.arn
  protocol  = "email"
  endpoint  = var.alarm_email # the subscription must be confirmed from the e-mail received
}

# Custom metric VPN/TunnelUp (1 = CHILD_SA installed, 0 = down) is published every minute by gw-aws.
# Missing data is treated as a failure: a dead gateway must raise the alarm too.
resource "aws_cloudwatch_metric_alarm" "tunnel_down" {
  alarm_name          = "${var.project}-tunnel-down"
  alarm_description   = "IPsec tunnel to the on-premises site is down"
  namespace           = "VPN"
  metric_name         = "TunnelUp"
  dimensions          = { Gateway = var.gateway_id }
  statistic           = "Minimum"
  period              = 60
  evaluation_periods  = 2
  threshold           = 1
  comparison_operator = "LessThanThreshold"
  treat_missing_data  = "breaching"
  alarm_actions       = [aws_sns_topic.alarms.arn]
  ok_actions          = [aws_sns_topic.alarms.arn]
}
