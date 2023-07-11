variable "vpc_cidr" {
    type = string
    default = "10.10.0.0/16"
}

variable "pub_cidr"{
    type = list(string)
    default = ["10.10.0.0/20","10.10.16.0/20"]
}

variable "az-pu"{
    type = list(string)
    default = ["us-east-1a","us-east-1b"]
}

variable "az-pr"{
    type = list(string)
    default = ["us-east-1c","us-east-1d"]
}

variable "pri_cidr"{
    type = list(string)
    default = ["10.10.32.0/20","10.10.48.0/20"]
}

variable "key_name"{
    type = string
    default = "task2-key"
}

variable "inc_type"{
    type = string
    default ="t2.micro"
}

variable "ec2_count_pub"{
    type = number
    default = 1
}

variable "ec2_count_pri"{
    type = number
    default = 2
}

variable "alb_name"{
    type = string
    default ="task2-alb"
}

variable "tg_name"{
    type = string
    default ="task2-tg"
}

variable "tg_protocol"{
    type = string
    default ="HTTP"
}

variable "tg_port"{
    type = string
    default = "80"
}

variable "db_name"{
    type = string
    default = "task2"
}

variable "db_user"{
    type = string
    default = "admin"
}

variable "db_passwd"{
    type = string
    default = "admin123"
}


