# ---------------------------------------------------------
# IAM Role for EC2 (CloudWatch + ECR access)
# ---------------------------------------------------------
resource "aws_iam_role" "ec2_role" {
  name = "ecom-ec2-monitoring-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect    = "Allow",
      Principal = { Service = "ec2.amazonaws.com" },
      Action    = "sts:AssumeRole"
    }]
  })
}

# ---------------------------------------------------------
# IAM Policy: CloudWatch Read-Only
# ---------------------------------------------------------
resource "aws_iam_policy" "ec2_monitoring_policy" {
  name = "ecom-ec2-monitoring-policy"

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Sid    = "CloudWatchMetrics"
        Effect = "Allow"
        Action = [
          "cloudwatch:GetMetricData",
          "cloudwatch:GetMetricStatistics",
          "cloudwatch:ListMetrics"
        ]
        Resource = "*"
      }
    ]
  })
}

# ---------------------------------------------------------
# IAM Policy: ECR Push + Repo Create
# ---------------------------------------------------------
resource "aws_iam_policy" "ec2_ecr_policy" {
  name = "ecom-ec2-ecr-policy"

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Sid    = "ECRPushPermissions",
        Effect = "Allow",
        Action = [
          "ecr:GetAuthorizationToken",
          "ecr:BatchCheckLayerAvailability",
          "ecr:CompleteLayerUpload",
          "ecr:UploadLayerPart",
          "ecr:InitiateLayerUpload",
          "ecr:PutImage",
          "ecr:DescribeRepositories",
          "ecr:CreateRepository"
        ],
        Resource = "*"
      }
    ]
  })
}

# ---------------------------------------------------------
# Attach both policies to EC2 role
# ---------------------------------------------------------
resource "aws_iam_role_policy_attachment" "ec2_monitoring_attach" {
  role       = aws_iam_role.ec2_role.name
  policy_arn = aws_iam_policy.ec2_monitoring_policy.arn
}

resource "aws_iam_role_policy_attachment" "ec2_ecr_attach" {
  role       = aws_iam_role.ec2_role.name
  policy_arn = aws_iam_policy.ec2_ecr_policy.arn
}

# ---------------------------------------------------------
# Instance Profile (attach IAM role to EC2)
# ---------------------------------------------------------
resource "aws_iam_instance_profile" "ec2_instance_profile" {
  name = "ecom-ec2-instance-profile"
  role = aws_iam_role.ec2_role.name
}
