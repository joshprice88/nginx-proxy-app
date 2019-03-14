provider "aws" {
	region = "${var.aws_region}"	
}


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


#------Security Groups and Rules------

resource "aws_security_group" "project_rp_sg" {
	name = "project_rp_sg"
	description = "Used for reverse proxy instance"
	vpc_id = "${aws_vpc.project_vpc.id}"
}

resource "aws_security_group" "project_bastion_sg" {
        name = "project_bastion_sg"
        description = "Used for ssh access to bastion host"
        vpc_id = "${aws_vpc.project_vpc.id}"
}

resource "aws_security_group" "calibre_sg" {
	name = "calibre_sg"
	description = "Security group for calibre instances"
	vpc_id = "${aws_vpc.project_vpc.id}"
}

resource "aws_security_group" "calibre_elb_sg" {
	name = "calibre_elb_sg"
	description = "Security group for the calibre load balancer"
	vpc_id = "${aws_vpc.project_vpc.id}"
}

resource "aws_security_group_rule" "allow_http_inbound" {
	type = "ingress"

	from_port   = 80
	to_port     = 80
    	protocol    = "tcp"
    	cidr_blocks = ["0.0.0.0/0"]
	
	security_group_id = "${aws_security_group.project_rp_sg.id}"

}

resource "aws_security_group_rule" "allow_ssh_inbound" {
        type = "ingress"

        from_port   = 22
        to_port     = 22
        protocol    = "tcp"
        cidr_blocks = ["0.0.0.0/0"]

        security_group_id = "${aws_security_group.project_bastion_sg.id}"

}

resource "aws_security_group_rule" "allow_ssh_from_bastion" {
        type = "ingress"
        
        from_port   = 22
        to_port     = 22
        protocol    = "tcp"
        source_security_group_id = "${aws_security_group.project_bastion_sg.id}"
        security_group_id = "${aws_security_group.project_rp_sg.id}"

}

resource "aws_security_group_rule" "allow_all_outbound_sg" {
        type = "egress"

        from_port   = 0
        to_port     = 0
        protocol    = "-1"

	cidr_blocks = ["0.0.0.0/0"]

	security_group_id = "${aws_security_group.project_rp_sg.id}"

}

resource "aws_security_group_rule" "allow_all_outbound_bastion" {
        type = "egress"

        from_port   = 0
        to_port     = 0
        protocol    = "-1"

	cidr_blocks = ["0.0.0.0/0"]

        security_group_id = "${aws_security_group.project_bastion_sg.id}"

}

resource "aws_security_group_rule" "allow_8083_inbound" {
        type = "ingress"

        from_port   = 8083
        to_port     = 8083
        protocol    = "tcp"
        source_security_group_id = "${aws_security_group.calibre_elb_sg.id}"
        
        security_group_id = "${aws_security_group.calibre_sg.id}"
}

resource "aws_security_group_rule" "allow_all_outbound_calibre" {
        type = "egress"

        from_port   = 0
        to_port     = 0
        protocol    = "-1"

        cidr_blocks = ["0.0.0.0/0"]

        security_group_id = "${aws_security_group.calibre_sg.id}"
}

resource "aws_security_group_rule" "allow_ssh_from_bastion_calibre" {
        type = "ingress"

        from_port   = 22
        to_port     = 22
        protocol    = "tcp"
        source_security_group_id = "${aws_security_group.project_bastion_sg.id}"
        security_group_id = "${aws_security_group.calibre_sg.id}"

}

resource "aws_security_group_rule" "allow_all_outbound_calibre_elb" {
        type = "egress"

        from_port   = 0
        to_port     = 0
        protocol    = "-1"

        cidr_blocks = ["0.0.0.0/0"]

        security_group_id = "${aws_security_group.calibre_elb_sg.id}"
}


resource "aws_security_group_rule" "allow_http_inbound_elb" {
        type = "ingress"

        from_port   = 80
        to_port     = 80
        protocol    = "tcp"
        cidr_blocks = ["0.0.0.0/0"]

        security_group_id = "${aws_security_group.calibre_elb_sg.id}"
}

#------Compute-----

resource "aws_key_pair" "project_auth" {
	key_name   = "${var.key_name}"
	public_key = "${file(var.public_key_path)}"
}

resource "aws_instance" "nginx_rp" {
	instance_type = "${var.nginx_instance_type}"
	ami = "${var.nginx_instance_ami}"

	tags {
		Name = "project_nginx_rp"
	}
	
	subnet_id = "${aws_subnet.public_subnets.*.id[0]}"
	vpc_security_group_ids = ["${aws_security_group.project_rp_sg.id}"]
	key_name = "${aws_key_pair.project_auth.id}"
	
	user_data = "${file(var.nginx_userdata_path)}"
}

resource "aws_instance" "calibre_bastion" {
        instance_type = "${var.bastion_instance_type}"
        ami = "${var.bastion_instance_ami}"

        tags {
                Name = "project_nginx_bastion"
        }

        subnet_id = "${aws_subnet.public_subnets.*.id[0]}"
        vpc_security_group_ids = ["${aws_security_group.project_bastion_sg.id}"]
		key_name = "${aws_key_pair.project_auth.id}"
		
		provisioner "file" {
			source = "${var.private_key_path}"
			destination = "/home/ec2-user/.ssh/id_rsa"
			
			connection {
				type = "ssh"
				user = "ec2-user"
				private_key = "${file("${var.private_key_path}")}"
			}
		}
}

resource "aws_elb" "calibre_elb" {
	name = "calibre-elb"
	subnets = ["${aws_subnet.public_subnets.*.id}"]

	security_groups = ["${aws_security_group.calibre_elb_sg.id}"]

	listener {
		instance_port = 8083
		instance_protocol = "http"
		lb_port = 80
		lb_protocol = "http"
	}

	health_check {
		healthy_threshold = "${var.calibre_elb_healthy_threshold}"
		unhealthy_threshold = "${var.calibre_elb_unhealthy_threshold}"
		timeout = "${var.calibre_elb_timeout}"
		target = "TCP:8083"
		interval = "${var.calibre_elb_interval}"
	}

	cross_zone_load_balancing = true
	idle_timeout = 120
	connection_draining = true
	connection_draining_timeout = 120

	tags {
		Name = "calibre-elb"
	}
}
	
resource "aws_launch_configuration" "calibre_lc" {
	name_prefix = "cal-lc-"
	instance_type = "${var.calibre_instance_type}"
	image_id = "${var.calibre_instance_ami}"
	security_groups = ["${aws_security_group.calibre_sg.id}"]
	key_name = "${aws_key_pair.project_auth.id}"	
	user_data = "${file(var.calibre_userdata_path)}"
	
	lifecycle {
		create_before_destroy = true
	}
}

resource "aws_autoscaling_group" "calibre-asg" {
	name = "asg-${aws_launch_configuration.calibre_lc.id}"
	max_size = "${var.calibre_asg_max}"
	min_size = "${var.calibre_asg_min}"
	health_check_grace_period = "${var.calibre_asg_grace}"
	health_check_type = "${var.calibre_asg_hct}"
	desired_capacity = "${var.calibre_asg_cap}"
	force_delete = true
	load_balancers = ["${aws_elb.calibre_elb.id}"]
	
	vpc_zone_identifier = ["${aws_subnet.private_subnets.*.id}"]

	launch_configuration = "${aws_launch_configuration.calibre_lc.name}"

	tag {
		key = "Name"
		value = "calibre_asg-instance"
		propagate_at_launch = true
	}

	lifecycle {
		create_before_destroy = true
	}

}



























