provider "aws" {

    region  = "us-east-1"

}

locals {
    env = "task2"
    ingress_rule = [{
        port = 80
        description = "Ingress rules for http"
    },
    {
        port = 443
        description = "Ingress rules for https"

    },
    {
        port = 22
        description = "Ingress rules for ssh"

    }]
}

# Creating VPC

resource "aws_vpc" "task2_vpc" {

    cidr_block = var.vpc_cidr
    enable_dns_hostnames = true

    tags = {
        Name = title("${local.env}-vpc")
    }

}

# Creating subnets

resource "aws_subnet" "public_sub"{
    count = length(var.pub_cidr)
    vpc_id = aws_vpc.task2_vpc.id
    cidr_block = element(var.pub_cidr,count.index)
    availability_zone = element(var.az-pu,count.index)

    tags = {
        Name = "task-subnet-public"
    }
}

resource "aws_subnet" "pri_sub" {
    count = length(var.pri_cidr)
    vpc_id = aws_vpc.task2_vpc.id
    cidr_block = element(var.pri_cidr,count.index)
    availability_zone = element(var.az-pu,count.index)

    tags = {
        Name = "task-subnet-private"
    }
}

# Internet gateway

resource "aws_internet_gateway" "task-ig" {

    vpc_id = aws_vpc.task2_vpc.id

    tags = {
      Name = "task-igw"
    }
  
}

# Elatic IP (for private network instances internet connection)

resource "aws_eip" "task-pr-eip" {
  
  vpc = true
  depends_on = [ aws_internet_gateway.task-ig ]

  tags = {
    Name = "task-eip-for-pr"
  }

}

# Nat gateway

resource "aws_nat_gateway" "task-pr-nat" {

    allocation_id = aws_eip.task-pr-eip.id
    subnet_id = element(aws_subnet.public_sub.*.id,0)
    depends_on = [ aws_internet_gateway.task-ig,aws_eip.task-pr-eip ]
  
}

# Route table

resource "aws_route_table" "public" {

    vpc_id = aws_vpc.task2_vpc.id

    tags = {
        Name = "task-public-rt"
    }

}

# routes for public
resource "aws_route" "public_routes" {

    route_table_id = aws_route_table.public.id
    destination_cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.task-ig.id

}

resource "aws_route_table_association" "public_subnet" {

    count = length(aws_subnet.public_sub.*.id)
    subnet_id = element(aws_subnet.public_sub.*.id,count.index)
    route_table_id = aws_route_table.public.id
  
}

resource "aws_route_table" "private" {

    vpc_id = aws_vpc.task2_vpc.id
    tags = {
        Name = "task-private-rt"
    }
  
}

resource "aws_route" "private_route" {

    route_table_id = aws_route_table.private.id
    destination_cidr_block = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.task-pr-nat.id

}

resource "aws_route_table_association" "pri_sub" {

    count = length(aws_subnet.pri_sub.*.id)
    subnet_id = element(aws_subnet.pri_sub.*.id,count.index)
    route_table_id = aws_route_table.private.id
  
}

resource "aws_security_group" "taks2-sg" {

    vpc_id = aws_vpc.task2_vpc.id

    dynamic "ingress"{

        for_each = local.ingress_rule
        content {
            description = ingress.value.description
            from_port = ingress.value.port
            to_port = ingress.value.port
            protocol = "tcp"
            cidr_blocks  = ["0.0.0.0/0"]

        }
    }

    egress {
        from_port = 0
        to_port = 0
        protocol = "-1"
        cidr_blocks = ["0.0.0.0/0"]

    }
  
}

resource "tls_private_key" "task_key" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "aws_key_pair" "task_key_pair" {
  key_name   = var.key_name
  public_key = tls_private_key.task_key.public_key_openssh
  
  provisioner "local-exec" {
    command = "echo '${tls_private_key.task_key.private_key_pem}' > ${var.key_name}.pem"
  }
}

data "aws_ami" "task2-amz"{

    filter{
        name = "name"
        values = ["al2023-ami-2023.0.20230419.0-kernel-6.1-x86_64"]
    }
    most_recent = true
    owners = ["137112412989"]
}

resource "aws_instance" "task2-pub-ec2" {
    ami = data.aws_ami.task2-amz.id
    instance_type = var.inc_type
    count = var.ec2_count_pub
    subnet_id = element(aws_subnet.public_sub.*.id,count.index)
    user_data = file("apache_install.sh")
    vpc_security_group_ids = [aws_security_group.taks2-sg.id]
    key_name = aws_key_pair.task_key_pair.key_name
    associate_public_ip_address = true

}

resource "aws_instance" "task2-pri-ec2" {
    ami = data.aws_ami.task2-amz.id
    instance_type = var.inc_type
    count = var.ec2_count_pri
    subnet_id = element(aws_subnet.pri_sub.*.id,count.index)
    user_data = file("apache_install.sh")
    vpc_security_group_ids = [aws_security_group.taks2-sg.id]
    key_name = aws_key_pair.task_key_pair.key_name

}

resource "aws_security_group" "alb-sg" {
  vpc_id =  aws_vpc.task2_vpc.id
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = {
    Name = title("${local.env}-alb-sg")
  }
}

resource "aws_lb" "task2-alb" {
    name = var.alb_name
    internal           = false
    load_balancer_type = "application"
    security_groups    = [aws_security_group.alb-sg.id]
    subnets            = [element(aws_subnet.public_sub.*.id,0),element(aws_subnet.public_sub.*.id,1)]

    tags = {
    Environment = "${var.alb_name}"
  }
  
}

resource "aws_lb_target_group" "task2-tg" {
    name     = var.tg_name
    port     = var.tg_port
    protocol = var.tg_protocol
    vpc_id   = aws_vpc.task2_vpc.id

    health_check  {
        enabled             = true
        interval            = 30
        path                = "/"
        port                = var.tg_port
        healthy_threshold   = 3
        unhealthy_threshold = 3
        timeout             = 6
        protocol            = var.tg_protocol
        matcher             = "200-300"
}

      tags = {
    Name = "${var.tg_name}"
}

}

resource "aws_lb_target_group_attachment" "task2-alb-tg-attach" {
    count               = length(aws_instance.task2-pri-ec2.*.id)
    target_group_arn    =  aws_lb_target_group.task2-tg.arn
    target_id           =  element(aws_instance.task2-pri-ec2.*.id,count.index)
    port                = var.tg_port

}

resource "aws_lb_listener" "http-listner" {
    load_balancer_arn = aws_lb.task2-alb.arn
    port              = var.tg_port
    protocol          = var.tg_protocol

    default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.task2-tg.arn
  }

}

resource "aws_security_group_rule" "aws-ec2" {
  type              = "ingress"
  from_port         = "80"
  to_port           = "80"
  protocol          = "tcp"
  source_security_group_id = aws_security_group.alb-sg.id
  security_group_id = aws_security_group.taks2-sg.id
}


# RDS

resource "aws_security_group" "rds-sg" {

  vpc_id = aws_vpc.task2_vpc.id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "rds-sg"
  }
}

resource "aws_db_parameter_group" "task2-dbpg" {
  name   = "task2"
  family = "mysql8.0"

  parameter {
    name  = "character_set_server"
    value = "utf8"
  }

  parameter {
    name  = "character_set_client"
    value = "utf8"
  }
}

resource "aws_db_subnet_group" "task2-subnet-group" {
  name       = "task2-subnet-group"
  subnet_ids = [element(aws_subnet.public_sub.*.id,0),element(aws_subnet.public_sub.*.id,1)]
}


resource "aws_db_instance" "task2-rds" {
    allocated_storage    = 10
    vpc_security_group_ids = [aws_security_group.rds-sg.id]
    db_subnet_group_name    = aws_db_subnet_group.task2-subnet-group.id
    db_name              = var.db_name
    engine               = "mysql"
    instance_class       = var.db_instance_type
    username             = var.db_user
    password             = var.db_passwd
    parameter_group_name   = aws_db_parameter_group.task2-dbpg.name
    skip_final_snapshot  = true
  
}

resource "aws_security_group_rule" "rds-ec2-sg" {
  type              = "ingress"
  from_port         = "3306"
  to_port           = "3306"
  protocol          = "tcp"
  source_security_group_id = aws_security_group.taks2-sg.id
  security_group_id = aws_security_group.rds-sg.id

}