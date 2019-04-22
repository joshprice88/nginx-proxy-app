output "nginx_ip" {
	value = "${aws_instance.nginx_rp.public_ip}"
}

output "books_nfs" {
	value = "${aws_efs_mount_target.books-mount-target.0.dns_name}"
}

output "bastion_ip" {
	value = "${aws_instance.calibre_bastion.public_ip}"
}
