variable "region" {
  type    = string
  default = "eu-north-1"
}

variable "vpc_cidr" {
  type    = string
  default = "10.1.0.0/16"
}

variable "instance_type" {
  type    = string
  default = "t3.small"
}

variable "bastion_allowed_ip" {
  type = string
}

variable "key_name" {
  type    = string
  default = "my-free-key-for-devops-training-server"
}

variable "bucket_name" {
  type    = string
  default = "ebotprog-week6-staging-milestone-bucket"
}

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
