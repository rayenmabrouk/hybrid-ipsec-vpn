data "aws_ssm_parameter" "ubuntu" {
  name = "/aws/service/canonical/ubuntu/server/26.04/stable/current/amd64/hvm/ebs-gp3/ami-id"
}

data "aws_availability_zones" "available" {
  state = "available"
}

module "network" {
  source = "./modules/network"

  project               = var.project
  vpc_cidr              = var.vpc_cidr
  public_subnet_cidr    = var.public_subnet_cidr
  private_subnet_cidr   = var.private_subnet_cidr
  availability_zone     = data.aws_availability_zones.available.names[0]
  flow_logs_bucket_name = var.flow_logs_bucket_name
}

module "gateway" {
  source = "./modules/gateway"

  project                = var.project
  vpc_id                 = module.network.vpc_id
  subnet_id              = module.network.public_subnet_id
  private_route_table_id = module.network.private_route_table_id
  private_ip             = var.gateway_private_ip
  ami_id                 = data.aws_ssm_parameter.ubuntu.value
  instance_type          = var.instance_type
  instance_profile_name  = var.instance_profile_name
  onprem_public_ip       = var.onprem_public_ip
  onprem_cidr            = var.onprem_cidr
  private_subnet_cidr    = var.private_subnet_cidr
}

module "app" {
  source = "./modules/app"

  project               = var.project
  vpc_id                = module.network.vpc_id
  subnet_id             = module.network.private_subnet_id
  private_ip            = var.app_private_ip
  ami_id                = data.aws_ssm_parameter.ubuntu.value
  instance_type         = var.instance_type
  instance_profile_name = var.instance_profile_name
  onprem_cidr           = var.onprem_cidr

  # The app installs nginx at boot through gw-aws (NAT instance): the default route must exist first.
  depends_on = [module.gateway]
}

module "monitoring" {
  source = "./modules/monitoring"

  project     = var.project
  alarm_email = var.alarm_email
  gateway_id  = "gw-aws"
}
