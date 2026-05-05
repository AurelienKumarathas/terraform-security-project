# Secure EC2 Instance Module
# Enforces IMDSv2, KMS EBS encryption, detailed monitoring, no public IP
# Variables are defined in variables.tf — outputs in outputs.tf

# IAM role for EC2 — required for SSM Session Manager access (no public IP / no bastion)
# Also satisfies CKV2_AWS_41: Ensure an IAM role is attached to EC2 instance
resource "aws_iam_role" "this" {
  name = var.iam_role_name

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "EC2AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = {
    Name        = var.iam_role_name
    Environment = var.environment
    Owner       = var.owner
    CostCenter  = var.cost_center
    ManagedBy   = "terraform"
  }
}

# Attach AWS-managed SSM policy so Session Manager works without opening SSH
resource "aws_iam_role_policy_attachment" "ssm" {
  role       = aws_iam_role.this.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "this" {
  name = var.iam_role_name
  role = aws_iam_role.this.name
}

resource "aws_instance" "this" {
  ami           = var.ami_id
  instance_type = var.instance_type
  subnet_id     = var.subnet_id

  vpc_security_group_ids = var.security_group_ids
  iam_instance_profile   = aws_iam_instance_profile.this.name

  # SECURITY: Require IMDSv2 — prevents SSRF credential theft (cf. Capital One 2019)
  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 1
    instance_metadata_tags      = "disabled"
  }

  # SECURITY: Encrypted root volume with customer-managed KMS key
  root_block_device {
    volume_size           = 50
    volume_type           = "gp3"
    encrypted             = true
    kms_key_id            = var.kms_key_id
    delete_on_termination = true
  }

  # SECURITY: Enable detailed CloudWatch monitoring
  monitoring = true

  # SECURITY: No public IP — access via SSM Session Manager only
  associate_public_ip_address = false

  tags = {
    Name        = var.instance_name
    Environment = var.environment
    Owner       = var.owner
    CostCenter  = var.cost_center
    ManagedBy   = "terraform"
  }
}
