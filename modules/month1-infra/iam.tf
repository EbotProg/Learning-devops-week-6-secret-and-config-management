resource "aws_iam_role" "ec2_repository_role" {
  name = "${var.environment}-ec2-repository-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "ecr_access" {
  role       = aws_iam_role.ec2_repository_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryFullAccess"
}

resource "aws_iam_instance_profile" "ec2_repository_profile" {
  name = "${var.environment}-ec2-repository-role"
  role = aws_iam_role.ec2_repository_role.name
}

# New in Week 6 — lets the instance pull secrets at boot instead of having
# them baked into user_data as plaintext.
resource "aws_iam_role_policy" "read_secrets" {
  name = "${var.environment}-read-parse-stack-secrets"
  role = aws_iam_role.ec2_repository_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["secretsmanager:GetSecretValue"]
        Resource = [aws_secretsmanager_secret.mongo_password.arn]
      },
      {
        Effect   = "Allow"
        Action   = ["ssm:GetParameter"]
        Resource = ["arn:aws:ssm:${var.region}:${data.aws_caller_identity.current.account_id}:parameter/${var.environment}/parse-stack/*"]
      }
    ]
  })
}
