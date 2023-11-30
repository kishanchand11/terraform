terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.16"
    }
  }

  required_version = ">= 1.2.0"
}

### vpc 

provider "aws" {
  region  = "us-east-1"
  access_key = ""
  secret_key = ""
}

resource "aws_vpc" "terra_vpc" {
  cidr_block = "10.0.0.0/16"
}

##subnets

resource "aws_subnet" "subnet-1" {
  vpc_id     = aws_vpc.terra_vpc.id
  cidr_block = "10.0.1.0/24"
   availability_zone = "us-east-1a"     
  tags = {
    Name = "terra-subnet1"
  }
  }
resource "aws_subnet" "subnet-2" {
  vpc_id     = aws_vpc.terra_vpc.id
  cidr_block = "10.0.2.0/24"
   availability_zone = "us-east-1a"     
  tags = {
    Name = "terra-subnet2"
  }
  }
###igw

resource "aws_internet_gateway" "gw" {
  vpc_id = aws_vpc.terra_vpc.id

  tags = {
    Name = "terraigw"
  }
}

###

resource "aws_route_table" "terra-route-table" {
  vpc_id = aws_vpc.terra_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.gw.id
  }

  route {
    ipv6_cidr_block        = "::/0"
    gateway_id = aws_internet_gateway.gw.id
  }

  tags = {
    Name = "terraroute"
  }
}

### route table association

resource "aws_route_table_association" "rt-assoc" {
  subnet_id      = aws_subnet.subnet-1.id
  route_table_id = aws_route_table.terra-route-table.id
}


### sg groups

resource "aws_security_group" "allow_web" {
  name        = "allow_web_traffic"
  description = "Allow web inbound traffic"
  vpc_id      = aws_vpc.terra_vpc.id

ingress {
    description      = "HTTPS"
    from_port        = 443
    to_port          = 443
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
  }
ingress {
    description      = "HTTP"
    from_port        = 80
    to_port          = 80
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
}
ingress {
    description      = "SSH"
    from_port        = 22
    to_port          = 22
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
}


  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  tags = {
    Name = "allow_web"
  }
}

######### network interface

resource "aws_network_interface" "ntwk-face" {
  subnet_id       = aws_subnet.subnet-1.id
  private_ips     = ["10.0.1.50"]
  security_groups = [aws_security_group.allow_web.id]

}

####### assign elastic ip to network interface

resource "aws_eip" "one" {
  domain                    = "vpc"
  network_interface         = aws_network_interface.ntwk-face.id
  associate_with_private_ip = "10.0.1.50"
  depends_on  				= [aws_internet_gateway.gw]
}

#######

resource "aws_instance" "terraform_instance" {
  ami           = "need to provide ubuntu image id"
  instance_type = "t2.micro"
  availability_zone = "us-east-1a"
  key_name = "devops"

  network_interface{
    device_index = 0
	network_interface_id = aws_network_interface.ntwk-face.id
  }
  

user_data = <<-EOF
#!/bin/bash
sudo apt update -y
sudo apt install apache2 -y
sudo systemctl start apache2
sudo echo 'your first web server' > /var/www/html/index.html
EOF 
tags = {
    Name = "web-server"
  }
}

