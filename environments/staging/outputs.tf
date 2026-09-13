output "bastion_public_ip" { value = module.infra.bastion_public_ip }
output "app_public_ip" { value = module.infra.app_public_ip }
output "app_urls" { value = module.infra.app_urls }
output "s3_website_endpoint" { value = module.infra.s3_website_endpoint }
