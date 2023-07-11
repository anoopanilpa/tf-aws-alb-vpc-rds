output "pub-pub-ec2" {
    value = ["${aws_instance.task2-pub-ec2.*.public_ip}"]
}

output "pri-pub-ec2" {
    value = ["${aws_instance.task2-pub-ec2.*.private_ip}"]
}

output "pri-pri-ec2" {
    value = ["${aws_instance.task2-pri-ec2.*.private_ip}"]
}

output "alb_dns_name" {

    value = aws_lb.task2-alb.dns_name
}


output "rds_hostname" {
    value = aws_db_instance.task2-rds.address
}

