# Mongo's root password goes in Secrets Manager — this is the one credential
# where rotation genuinely matters (a database password you'd want to rotate
# on a schedule in a real setup).
resource "aws_secretsmanager_secret" "mongo_password" {
  name = "${var.environment}/parse-stack/mongo-root-password"
  recovery_window_in_days = 0
}

resource "aws_secretsmanager_secret_version" "mongo_password" {
  secret_id     = aws_secretsmanager_secret.mongo_password.id
  secret_string = var.mongo_root_password
}

# Everything else is static application config that doesn't rotate on a
# schedule — Parameter Store (SecureString) covers it for free.
resource "aws_ssm_parameter" "parse_master_key" {
  name  = "/${var.environment}/parse-stack/parse-master-key"
  type  = "SecureString"
  value = var.parse_master_key
}

resource "aws_ssm_parameter" "parse_app_id" {
  name  = "/${var.environment}/parse-stack/parse-app-id"
  type  = "SecureString"
  value = var.parse_app_id
}

resource "aws_ssm_parameter" "dashboard_user" {
  name  = "/${var.environment}/parse-stack/dashboard-user"
  type  = "SecureString"
  value = var.dashboard_user
}

resource "aws_ssm_parameter" "dashboard_password" {
  name  = "/${var.environment}/parse-stack/dashboard-password"
  type  = "SecureString"
  value = var.dashboard_password
}
