provider "aws" {
        region = "${var.aws_region}"
}

#------Compute-----

resource "aws_key_pair" "project_auth" {
	key_name   = "${var.key_name}"
	public_key = "${file(var.public_key_path)}"
}

data "template_file" "nginx_install" {
  template = "${file(var.nginx_userdata_path)}"
  vars = {
    aws_lb_dns = "${aws_elb.calibre_elb.dns_name}"
  }
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
	
	user_data = "${data.template_file.nginx_install.rendered}"
	depends_on = ["aws_elb.calibre_elb"]
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

data "template_file" "calibre-install" {
  template = "${file(var.calibre_userdata_path)}"
  vars = {
    nfs_mount_path = "${aws_efs_mount_target.books-mount-target.0.dns_name}"
  }
}
	
resource "aws_launch_configuration" "calibre_lc" {
	name_prefix = "cal-lc-"
	instance_type = "${var.calibre_instance_type}"
	image_id = "${var.calibre_instance_ami}"
	security_groups = ["${aws_security_group.calibre_sg.id}", "${aws_security_group.nfs_sg.id}"]
	key_name = "${aws_key_pair.project_auth.id}"	
	user_data = "${data.template_file.calibre-install.rendered}"
	
	lifecycle {
		create_before_destroy = true
	}
	depends_on = ["aws_efs_file_system.books-dir"]
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

#----- Storage -----

resource "aws_efs_file_system" "books-dir" {
  creation_token = "books-dir"

  tags = {
    Name = "Books-Directory"
  }
}

resource "aws_efs_mount_target" "books-mount-target" {
	file_system_id = "${aws_efs_file_system.books-dir.id}"
	count = "${length(var.private_subnet_names)}"
	subnet_id = "${element(aws_subnet.private_subnets.*.id, count.index)}"
	security_groups = ["${aws_security_group.nfs_sg.id}"]
}





















