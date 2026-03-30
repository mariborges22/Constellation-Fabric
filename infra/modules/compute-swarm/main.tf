resource "aws_ecr_repository" "nakama" {
  name                 = "${var.project_name}-${var.environment}-nakama"
  image_tag_mutability = "MUTABLE"
  force_delete         = true
  image_scanning_configuration { scan_on_push = true }
}

# IAM Role for EC2 Swarm Nodes
resource "aws_iam_role" "swarm_node_role" {
  name = "${var.project_name}-${var.environment}-swarm-role-${var.region}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "ecr_read" {
  role       = aws_iam_role.swarm_node_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
}

resource "aws_iam_role_policy" "swarm_secrets_access" {
  name = "swarm-node-secrets-access"
  role = aws_iam_role.swarm_node_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["secretsmanager:GetSecretValue"]
        Resource = compact([var.tunnel_secret_arn, var.db_secret_arn, var.jwt_secret_arn])
      },
      {
        Effect   = "Allow"
        Action   = ["kms:Decrypt"]
        Resource = compact([var.rds_kms_arn])
      },
      {
        Effect   = "Allow"
        Action   = ["kinesis:PutRecord", "kinesis:PutRecords"]
        Resource = [var.kinesis_stream_arn]
      }
    ]
  })
}

resource "aws_iam_instance_profile" "swarm_node_profile" {
  name = "${var.project_name}-${var.environment}-swarm-profile-${var.region}"
  role = aws_iam_role.swarm_node_role.name
}

# Security Group for Swarm (already updated in networks module, but we reference it here)

# Launch Template for Swarm Nodes
resource "aws_launch_template" "swarm_node" {
  name_prefix   = "${var.project_name}-swarm-"
  image_id      = "ami-0e2c8ccd4e02226ad" # Amazon Linux 2023 in us-east-1 (check region if different)
  instance_type = var.instance_type

  network_interfaces {
    associate_public_ip_address = true
    security_groups             = [var.security_group_id]
  }

  iam_instance_profile {
    name = aws_iam_instance_profile.swarm_node_profile.name
  }

  user_data = base64encode(<<-EOF
              #!/bin/bash
              yum update -y
              yum install -y docker
              systemctl enable docker
              systemctl start docker
              usermod -a -G docker ec2-user
              
              # Initialize Swarm (for the first node)
              # In a real multi-node setup, we'd use a shared secret in S3 or DynamoDB to coordinate
              docker swarm init --advertise-addr $(curl -s http://169.254.169.254/latest/meta-data/local-ipv4) || true
              
              # Install cloudflared (optional if running as container, but good to have)
              EOF
  )

  tag_specifications {
    resource_type = "instance"
    tags = {
      Name = "${var.project_name}-swarm-node"
    }
  }
}

# Auto Scaling Group
resource "aws_autoscaling_group" "swarm" {
  name                = "${var.project_name}-swarm-asg"
  vpc_zone_identifier = var.subnet_ids
  desired_capacity    = 1
  min_size            = 1
  max_size            = 3

  launch_template {
    id      = aws_launch_template.swarm_node.id
    version = "$Latest"
  }

  tag {
    key                 = "Name"
    value               = "${var.project_name}-swarm-node"
    propagate_at_launch = true
  }
}
