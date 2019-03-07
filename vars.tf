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
