output "instance_id" { value = aws_instance.gateway.id }
output "public_ip" { value = aws_eip.gateway.public_ip }
output "security_group_id" { value = aws_security_group.gateway.id }
