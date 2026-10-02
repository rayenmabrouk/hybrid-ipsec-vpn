variable "region" {
  description = "AWS region (AWS Academy Learner Lab allows us-east-1 and us-west-2)."
  type        = string
  default     = "us-east-1"
}

variable "project" {
  description = "Project name, used for naming and tagging."
  type        = string
  default     = "hybrid-ipsec-vpn"
}

variable "onprem_public_ip" {
  description = "Public IPv4 address of the on-premises site (the only source allowed to reach IKE/NAT-T)."
  type        = string

  validation {
    condition     = can(cidrhost("${var.onprem_public_ip}/32", 0))
    error_message = "onprem_public_ip must be a single IPv4 address, e.g. 203.0.113.10."
  }
}

variable "onprem_cidr" {
  description = "On-premises LAN protected by the tunnel."
  type        = string
  default     = "10.10.0.0/24"
}

variable "vpc_cidr" {
  description = "CIDR block of the AWS VPC (remote site)."
  type        = string
  default     = "10.20.0.0/16"
}

variable "public_subnet_cidr" {
  description = "Public subnet hosting the VPN gateway."
  type        = string
  default     = "10.20.1.0/24"
}

variable "private_subnet_cidr" {
  description = "Private subnet hosting the application (no public IP)."
  type        = string
  default     = "10.20.2.0/24"
}

variable "gateway_private_ip" {
  description = "Fixed private IP of gw-aws."
  type        = string
  default     = "10.20.1.10"
}

variable "app_private_ip" {
  description = "Fixed private IP of app-aws."
  type        = string
  default     = "10.20.2.10"
}

variable "instance_type" {
  description = "EC2 instance type (Learner Lab: nano to large)."
  type        = string
  default     = "t3.micro"
}

variable "instance_profile_name" {
  description = "Existing instance profile (Learner Lab forbids creating IAM roles)."
  type        = string
  default     = "LabInstanceProfile"
}

variable "alarm_email" {
  description = "E-mail address notified when the tunnel goes down."
  type        = string
}

variable "flow_logs_bucket_name" {
  description = "Existing S3 bucket for VPC Flow Logs (created by scripts/bootstrap-aws.sh)."
  type        = string
}
