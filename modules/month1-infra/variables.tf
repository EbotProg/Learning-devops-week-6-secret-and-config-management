variable "environment" {
  type        = string
  description = "dev or staging — used to namespace names and secret paths"
}

variable "region" {
  type    = string
  default = "eu-north-1"
}

variable "vpc_cidr" {
  type        = string
  description = "e.g. 10.0.0.0/16 for dev, 10.1.0.0/16 for staging"
}

variable "instance_type" {
  type        = string
  default     = "t3.micro"
  description = "dev can stay t3.micro; staging might use t3.small"
}

variable "bastion_allowed_ip" {
  type        = string
  description = "Your own public IP (no /32 suffix — added automatically)"
}

variable "key_name" {
  type    = string
  default = "my-free-key-for-devops-training-server"
}

variable "bucket_name" {
  type        = string
  description = "Must be globally unique — include the environment name to avoid collisions"
}

# --- secrets — no defaults on purpose. A default here would be exactly the
# hardcoding this milestone exists to remove. Supply real values via a
# gitignored *.auto.tfvars file or TF_VAR_ environment variables, never a
# literal in a committed file. ---
variable "mongo_root_password" {
  type      = string
  sensitive = true
}

variable "parse_master_key" {
  type      = string
  sensitive = true
}

variable "parse_app_id" {
  type    = string
  default = "myAppId"
}

variable "dashboard_user" {
  type    = string
  default = "admin"
}

variable "dashboard_password" {
  type      = string
  sensitive = true
}
