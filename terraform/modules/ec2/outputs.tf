output "instance_id" {
  description = "ID of the created EC2 instance"
  value       = aws_instance.this.id
}

output "private_ip" {
  description = "Private IP address of the instance"
  value       = aws_instance.this.private_ip
}

output "instance_arn" {
  description = "ARN of the created EC2 instance"
  value       = aws_instance.this.arn
}
