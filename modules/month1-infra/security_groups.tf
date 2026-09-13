resource "aws_security_group" "bastion" {
  name        = "Bastion SG"
  description = "Allows ssh from only my ip address"
  vpc_id      = aws_vpc.main.id
}

resource "aws_vpc_security_group_ingress_rule" "bastion_ssh" {
  security_group_id = aws_security_group.bastion.id
  cidr_ipv4          = "${var.bastion_allowed_ip}/32"
  ip_protocol        = "tcp"
  from_port          = 22
  to_port            = 22
}

resource "aws_vpc_security_group_egress_rule" "bastion_out" {
  security_group_id = aws_security_group.bastion.id
  ip_protocol        = "tcp"
  from_port          = 22
  to_port            = 22
  cidr_ipv4          = "0.0.0.0/0"
}

resource "aws_security_group" "app_tier" {
  name        = "App-tier SG"
  description = "Allows ssh only from bastion"
  vpc_id      = aws_vpc.main.id
}

resource "aws_vpc_security_group_ingress_rule" "app_tier_ssh_from_bastion" {
  security_group_id            = aws_security_group.app_tier.id
  referenced_security_group_id = aws_security_group.bastion.id
  ip_protocol                  = "tcp"
  from_port                    = 22
  to_port                      = 22
}

resource "aws_vpc_security_group_egress_rule" "app_tier_out" {
  security_group_id = aws_security_group.app_tier.id
  ip_protocol        = "-1"
  cidr_ipv4          = "0.0.0.0/0"
}

resource "aws_security_group" "app_public" {
  name        = "App-public SG"
  description = "Direct access to the CRUD app ports, from my IP only"
  vpc_id      = aws_vpc.main.id
}

resource "aws_vpc_security_group_ingress_rule" "app_public_ssh" {
  security_group_id = aws_security_group.app_public.id
  cidr_ipv4          = "${var.bastion_allowed_ip}/32"
  ip_protocol        = "tcp"
  from_port          = 22
  to_port            = 22
}

resource "aws_vpc_security_group_ingress_rule" "app_public_frontend" {
  security_group_id = aws_security_group.app_public.id
  cidr_ipv4          = "${var.bastion_allowed_ip}/32"
  ip_protocol        = "tcp"
  from_port          = 3003
  to_port            = 3003
}

resource "aws_vpc_security_group_ingress_rule" "app_public_backend" {
  security_group_id = aws_security_group.app_public.id
  cidr_ipv4          = "${var.bastion_allowed_ip}/32"
  ip_protocol        = "tcp"
  from_port          = 1338
  to_port            = 1338
}

resource "aws_vpc_security_group_ingress_rule" "app_public_dashboard" {
  security_group_id = aws_security_group.app_public.id
  cidr_ipv4          = "${var.bastion_allowed_ip}/32"
  ip_protocol        = "tcp"
  from_port          = 4041
  to_port            = 4041
}

resource "aws_vpc_security_group_egress_rule" "app_public_out" {
  security_group_id = aws_security_group.app_public.id
  ip_protocol        = "-1"
  cidr_ipv4          = "0.0.0.0/0"
}
