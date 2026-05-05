output "instance_id" {
  description = "ID of the EC2 instance"
  value       = aws_instance.this.id
}

output "instance_arn" {
  description = "ARN of the EC2 instance"
  value       = aws_instance.this.arn
}

output "private_ip" {
  description = "Private IP of the EC2 instance"
  value       = aws_instance.this.private_ip
}

output "instance_profile_name" {
  description = "Name of the IAM instance profile attached to this EC2 instance"
  value       = aws_iam_instance_profile.this.name
}
