#------ VPC, Subnets, Internet Gateway, Routes ------

resource "aws_vpc" "project_vpc" {
        cidr_block = "${var.vpc_cidr}"
        enable_dns_hostnames = true
        enable_dns_support = true
}

#Define Subnets
resource "aws_subnet" "public_subnets" {
        count = "${length(var.public_subnet_names)}"
        vpc_id = "${aws_vpc.project_vpc.id}"
        cidr_block = "${element(var.public_subnet_cidrs, count.index)}"        

        availability_zone = "${element(var.public_subnet_zones, count.index)}" 

        map_public_ip_on_launch = true

        tags {
                Name = "subnet-${element(var.public_subnet_names, count.index)}"
        }
}

resource "aws_subnet" "private_subnets" {
        count = "${length(var.private_subnet_names)}"
        vpc_id = "${aws_vpc.project_vpc.id}"
        cidr_block = "${element(var.private_subnet_cidrs, count.index)}"       

        availability_zone = "${element(var.private_subnet_zones, count.index)}"

        map_public_ip_on_launch = false

        tags {
                Name = "subnet-${element(var.private_subnet_names, count.index)}"
        }
}

#Define Internet Gateway
resource "aws_internet_gateway" "project_internet_gw" {
        vpc_id = "${aws_vpc.project_vpc.id}"
        tags {
                Name = "project_internet_gw"
        }
}

#Define Route Tables
resource "aws_route_table" "public_rt" {
        vpc_id = "${aws_vpc.project_vpc.id}"

        route {
                cidr_block = "0.0.0.0/0"
                gateway_id = "${aws_internet_gateway.project_internet_gw.id}"  
        }

        tags {
                Name = "project-public"
        }
}

resource "aws_default_route_table" "private_rt" {
        default_route_table_id = "${aws_vpc.project_vpc.default_route_table_id}"

        route {
                cidr_block = "0.0.0.0/0"
                nat_gateway_id = "${aws_nat_gateway.calibre_nat_gw.id}"        
        }

        tags {
                Name = "project-private"
        }
}

#Associate Route Tables to Subnets
resource "aws_route_table_association" "public_assoc" {
        count = "${length(var.public_subnet_names)}"
        subnet_id = "${element(aws_subnet.public_subnets.*.id, count.index)}"  
        route_table_id = "${aws_route_table.public_rt.id}"
}

resource "aws_route_table_association" "private_assoc" {
        count = "${length(var.private_subnet_names)}"
        subnet_id = "${element(aws_subnet.private_subnets.*.id, count.index)}" 
        route_table_id = "${aws_default_route_table.private_rt.id}"
}

#NAT Gateway for private instances
resource "aws_eip" "nat_eip" {
        count    = "1"
        vpc = true
}

resource "aws_nat_gateway" "calibre_nat_gw" {
        allocation_id = "${aws_eip.nat_eip.id}"
        subnet_id = "${aws_subnet.public_subnets.*.id[0]}"

        tags = {
                Name = "calibre_gw"
  }
}
