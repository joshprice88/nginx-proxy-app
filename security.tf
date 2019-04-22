#------Security Groups and Rules------

#Define security groups
resource "aws_security_group" "calibre_rp_sg" {
        name = "calibre_rp_sg"
        description = "Used for reverse proxy instance"
        vpc_id = "${aws_vpc.project_vpc.id}"
}

resource "aws_security_group" "calibre_bastion_sg" {
        name = "calibre_bastion_sg"
        description = "Used for ssh access to bastion host"
        vpc_id = "${aws_vpc.project_vpc.id}"
}

resource "aws_security_group" "calibre_sg" {
        name = "calibre_sg"
        description = "Security group for calibre instances"
        vpc_id = "${aws_vpc.project_vpc.id}"
}

resource "aws_security_group" "nfs_sg" {
	name = "nfs_sg"
	description = "Allow 2049 in and out for nfs mount targets and ec2 hosts"
	vpc_id = "${aws_vpc.project_vpc.id}"
}

resource "aws_security_group" "calibre_elb_sg" {
        name = "calibre_elb_sg"
        description = "Security group for the calibre load balancer"       
        vpc_id = "${aws_vpc.project_vpc.id}"
}

#Define rules for reverse proxy
resource "aws_security_group_rule" "allow_http_inbound" {
        type = "ingress"

        from_port   = 80
        to_port     = 80
        protocol    = "tcp"
        cidr_blocks = ["0.0.0.0/0"]

        security_group_id = "${aws_security_group.calibre_rp_sg.id}"

}

resource "aws_security_group_rule" "allow_ssh_from_bastion" {
        type = "ingress"

        from_port   = 22
        to_port     = 22
        protocol    = "tcp"
        source_security_group_id = "${aws_security_group.calibre_bastion_sg.id}"       
        security_group_id = "${aws_security_group.calibre_rp_sg.id}"

}

resource "aws_security_group_rule" "allow_all_outbound_sg" {
        type = "egress"

        from_port   = 0
        to_port     = 0
        protocol    = "-1"

        cidr_blocks = ["0.0.0.0/0"]

        security_group_id = "${aws_security_group.calibre_rp_sg.id}"

}

#Define rules for bastion host
resource "aws_security_group_rule" "allow_ssh_inbound" {
        type = "ingress"

        from_port   = 22
        to_port     = 22
        protocol    = "tcp"
        cidr_blocks = ["0.0.0.0/0"]

        security_group_id = "${aws_security_group.calibre_bastion_sg.id}"

}

resource "aws_security_group_rule" "allow_all_outbound_bastion" {
        type = "egress"

        from_port   = 0
        to_port     = 0
        protocol    = "-1"

        cidr_blocks = ["0.0.0.0/0"]

        security_group_id = "${aws_security_group.calibre_bastion_sg.id}"
}

#Define rules for calibre-web servers
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
        source_security_group_id = "${aws_security_group.calibre_bastion_sg.id}"       
        security_group_id = "${aws_security_group.calibre_sg.id}"

}

#Define rules for elaestic load balancer
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

resource "aws_security_group_rule" "allow_nfs_traffic_inbound" {
	type = "ingress"

	from_port = 2049
	to_port = 2049
	protocol = "tcp"
	cidr_blocks = [
		"${aws_vpc.project_vpc.cidr_block}"
	]

	security_group_id = "${aws_security_group.nfs_sg.id}"
}

resource "aws_security_group_rule" "allow_nfs_traffic_outbound" {
        type = "egress"

        from_port = 2049
        to_port = 2049
	protocol = "tcp"
        cidr_blocks = [
                "${aws_vpc.project_vpc.cidr_block}"
        ]

	security_group_id = "${aws_security_group.nfs_sg.id}"
}

