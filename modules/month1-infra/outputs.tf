output "bastion_public_ip" {
  value = aws_instance.bastion.public_ip
}

output "app_private_ip" {
  value = aws_instance.app.private_ip
}

output "app_public_ip" {
  value = aws_instance.app_public.public_ip
}

output "app_urls" {
  value = {
    frontend  = "http://${aws_instance.app_public.public_ip}:3003"
    backend   = "http://${aws_instance.app_public.public_ip}:1338/parse/health"
    dashboard = "http://${aws_instance.app_public.public_ip}:4041"
  }
}

output "s3_website_endpoint" {
  value = aws_s3_bucket_website_configuration.milestone.website_endpoint
}
