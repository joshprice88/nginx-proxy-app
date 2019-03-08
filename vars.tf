variable "aws_region" {}
variable "project_name" {}

variable "vpc_cidr" {}

variable "public_subnet_names" {
	type = "list"
}
variable "public_subnet_cidrs" {
	type = "list"
}
variable "public_subnet_zones" {
	type = "list"
}

variable "private_subnet_names" {
        type = "list"
}
variable "private_subnet_cidrs" {
        type = "list"
}
variable "private_subnet_zones" {
        type = "list"
}

variable "key_name" {}
variable "public_key_path" {}

variable "nginx_instance_type" {}
variable "nginx_instance_ami" {}
variable "nginx_userdata_path" {}

variable "bastion_instance_type" {}
variable "bastion_instance_ami" {}

variable "calibre_instance_type" {}
variable "calibre_instance_ami" {}
variable "calibre_userdata_path" {}
