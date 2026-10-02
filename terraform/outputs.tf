output "gateway_public_ip" {
  description = "Elastic IP of gw-aws (remote_addrs of gw-onprem)."
  value       = module.gateway.public_ip
}

output "gateway_instance_id" {
  description = "Instance ID of gw-aws (SSM target)."
  value       = module.gateway.instance_id
}

output "app_instance_id" {
  description = "Instance ID of app-aws (SSM target)."
  value       = module.app.instance_id
}

output "app_private_ip" {
  description = "Private IP of the application, reachable only through the tunnel."
  value       = module.app.private_ip
}

output "flow_logs_bucket" {
  description = "S3 bucket receiving VPC Flow Logs."
  value       = module.network.flow_logs_bucket
}

output "alarm_topic_arn" {
  description = "SNS topic notified by the tunnel alarm."
  value       = module.monitoring.topic_arn
}
