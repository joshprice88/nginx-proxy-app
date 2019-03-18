provider "aws" {
        region = "${var.aws_region}"
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
	vpc_security_group_ids = ["${aws_security_group.calibre_rp_sg.id}"]
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
        vpc_security_group_ids = ["${aws_security_group.calibre_bastion_sg.id}"]
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



























