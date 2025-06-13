output "vpc_id" {
  description = "ID of the VPC"
  value       = aws_vpc.main.id
}

output "vpc_cidr_block" {
  description = "CIDR block of the VPC"
  value       = aws_vpc.main.cidr_block
}

output "public_subnet_ids" {
  description = "IDs of the public subnets"
  value       = aws_subnet.public[*].id
}

output "private_subnet_ids" {
  description = "IDs of the private subnets"
  value       = aws_subnet.private[*].id
}

output "web_server_instance_id" {
  description = "ID of the web server EC2 instance"
  value       = aws_instance.web_server.id
}

output "web_server_public_ip" {
  description = "Public IP address of the web server"
  value       = aws_instance.web_server.public_ip
}

output "web_server_public_dns" {
  description = "Public DNS name of the web server"
  value       = aws_instance.web_server.public_dns
}

output "database_endpoint" {
  description = "RDS instance endpoint"
  value       = aws_db_instance.main.endpoint
  sensitive   = true
}

output "database_port" {
  description = "RDS instance port"
  value       = aws_db_instance.main.port
}

output "key_pair_name" {
  description = "Name of the AWS key pair"
  value       = aws_key_pair.main.key_name
}

output "web_security_group_id" {
  description = "ID of the web server security group"
  value       = aws_security_group.web_server.id
}

output "database_security_group_id" {
  description = "ID of the database security group"
  value       = aws_security_group.database.id
}

output "application_url" {
  description = "URL to access the Magic 8-Ball application"
  value       = "http://magic8ball.${aws_instance.web_server.public_ip}.traefik.me"
}

output "traefik_dashboard_url" {
  description = "URL to access the Traefik dashboard"
  value       = "http://traefik.${aws_instance.web_server.public_ip}.traefik.me"
}

output "ssh_command" {
  description = "SSH command to connect to the web server"
  value       = "ssh -i ~/.ssh/${var.project_name}-key ec2-user@${aws_instance.web_server.public_ip}"
}

output "deployment_info" {
  description = "Deployment information for CI/CD"
  value = {
    instance_id   = aws_instance.web_server.id
    public_ip     = aws_instance.web_server.public_ip
    region        = var.aws_region
    app_url       = "http://magic8ball.${aws_instance.web_server.public_ip}.traefik.me"
    dashboard_url = "http://traefik.${aws_instance.web_server.public_ip}.traefik.me"
  }
} 