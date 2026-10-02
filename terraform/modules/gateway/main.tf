resource "aws_security_group" "gateway" {
  name        = "${var.project}-gw"
  description = "gw-aws: IKE/NAT-T from the on-prem site only; forwarded traffic from the private subnet"
  vpc_id      = var.vpc_id

  tags = { Name = "${var.project}-gw-sg" }
}

resource "aws_vpc_security_group_ingress_rule" "ike" {
  security_group_id = aws_security_group.gateway.id
  description       = "IKE from on-prem site"
  ip_protocol       = "udp"
  from_port         = 500
  to_port           = 500
  cidr_ipv4         = "${var.onprem_public_ip}/32"
}

resource "aws_vpc_security_group_ingress_rule" "nat_t" {
  security_group_id = aws_security_group.gateway.id
  description       = "IKE/ESP-in-UDP (NAT-T) from on-prem site"
  ip_protocol       = "udp"
  from_port         = 4500
  to_port           = 4500
  cidr_ipv4         = "${var.onprem_public_ip}/32"
}

resource "aws_vpc_security_group_ingress_rule" "from_private" {
  security_group_id = aws_security_group.gateway.id
  description       = "Traffic routed through the gateway by the private subnet (tunnel + NAT)"
  ip_protocol       = "-1"
  cidr_ipv4         = var.private_subnet_cidr
}

resource "aws_vpc_security_group_egress_rule" "all" {
  security_group_id = aws_security_group.gateway.id
  description       = "All outbound"
  ip_protocol       = "-1"
  cidr_ipv4         = "0.0.0.0/0"
}

resource "aws_instance" "gateway" {
  ami                    = var.ami_id
  instance_type          = var.instance_type
  subnet_id              = var.subnet_id
  private_ip             = var.private_ip
  vpc_security_group_ids = [aws_security_group.gateway.id]
  iam_instance_profile   = var.instance_profile_name
  source_dest_check      = false # required to route/NAT traffic that is not addressed to the instance itself

  user_data = templatefile("${path.module}/user_data.sh.tftpl", {
    private_subnet_cidr = var.private_subnet_cidr
    onprem_cidr         = var.onprem_cidr
  })
  user_data_replace_on_change = true

  metadata_options {
    http_tokens   = "required" # IMDSv2 only
    http_endpoint = "enabled"
  }

  root_block_device {
    volume_type = "gp3"
    volume_size = 8
    encrypted   = true
  }

  tags = { Name = "gw-aws" }
}

resource "aws_eip" "gateway" {
  domain   = "vpc"
  instance = aws_instance.gateway.id
  tags     = { Name = "${var.project}-gw-eip" }
}

# Everything leaving the private subnet goes through gw-aws: tunnel to on-prem and NAT to Internet.
resource "aws_route" "private_default" {
  route_table_id         = var.private_route_table_id
  destination_cidr_block = "0.0.0.0/0"
  network_interface_id   = aws_instance.gateway.primary_network_interface_id
}
