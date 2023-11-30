#1.Create vpc,#### Here the "prod_vpc" is name of instance #### tag name  production ####

resource "aws_instance" "prod_vpc" {
  ami           = data.aws_ami.ubuntu.id
  instance_type = "t3.micro"

  tags = {
    Name = "production"
  }
}

#2.###create igw internet gateway###
### "gw" is the name of gateway###


resource "aws_internet_gateway" "gw" {
  vpc_id = aws_vpc.prod_vpc.id

  tags = {
    Name = "main"
  }
}

#3. create route table ##########################
##### "prod-route-table" is name of route-table #####
##### "0.0.0.0/0" igw by default directs traffic to internet ###### aka default route
### aws_internet_gateway.gw.id ### gw is gateway_id######
########## "::/0" eqquivalent to default route aka all traffic #####

resource "aws_route_table" "prod-route-table" {
  vpc_id = aws_vpc.prod_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.gw.id
  }

  route {
    ipv6_cidr_block        = "::/0"
    gateway_id = aws_internet_gateway.gw.id
  }

  tags = {
    Name = "prod"
  }
}
########### "egress_only_gateway_id = aws_internet_gateway.gw.id" traffic from subnet will flow from igw to internet #################

#4. creat a subnet#
###### "subnet-1" is name of subnet

resource "aws_subnet" "subnet-1" {
  vpc_id     = aws_vpc.prod_vpc.id
  cidr_block = "10.0.1.0/24"
   availability_zone = "us-east-1a"      ##### availability_zone is optional
  tags = {
    Name = "prod-subnet"
  }
  
  
  
#5. associate subnet with route table# 
############# "a"is the name of route table association #######
 
 resource "aws_route_table_association" "a" {
  subnet_id      = aws_subnet.subnet-1.id
  route_table_id = aws_route_table.prod-route-table.id
}
}


#6. creating a security group#
########### "allow_web" is the resource name of sg #####
######"allow_web_traffic" / "Allow web inbound traffic" / random name #####
####### ingress decides which traffic should be allowed on which port ####
############# cidr_blocks = [aws_vpc.main.cidr_block] means ip address on internal computer with in priv network who can access ######
######### "egress" means allowing any traffic in egress direction  #####
###### "-1" means any protocol ###########

resource "aws_security_group" "allow_web" {
  name        = "allow_web_traffic"
  description = "Allow web inbound traffic"
  vpc_id      = aws_vpc.prod_vpc.id

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
    from_port        = 20
    to_port          = 20
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


#7. creating a network interface with an ip in the subnet that was created in step4#
####### "web-server-nic" is the resource name of nic ########
####### any ip from subnet apart from aws reserved ########

resource "aws_network_interface" "web-server-nic" {
  subnet_id       = aws_subnet.subnet-1.id
  private_ips     = ["10.0.1.50"]
  security_groups = [aws_security_group.allow_web.id]

  attachment {
    instance     = aws_instance.test.id
    device_index = 1
  }
}


#8.Assign an elastic ip to the network interface created in step 7#

##### domain - Indicates if this EIP is for use in VPC #####
#### igw needs to be deployed before eip ### else throws an error ####
#### EIP may require IGW to exist prior to association. Use depends_on to set an explicit dependency on the IGW. ######


resource "aws_eip" "one" {
  domain                    = "vpc"
  network_interface         = aws_network_interface.web-server-nic.id
  associate_with_private_ip = "10.0.1.50"
  depends_on  				= [aws_internet_gateway.gw]
}




#9.create ubuntu server and install/enable apache2#
####"web-server_instance" is name of resource #######


resource "aws_instance" "web-server_instance" {
  ami           = "need to provide ubuntu image id"
  instance_type = "t3.micro"
  availability_zone = "us-east-1a"
  key-name = "aws"

  network_interface{
    device_index = 0
	network_interface_id = aws_network_interface.web-server-nic.id
  }
  
  user_data = <<-EOF
               #!/bin/bash
			   sudo apt update -y
			   sudo apt install apache2 -y
			   sudo systemctl start apache2
			   sudo bash -c 'echo your first web server > /var/www/html/index.html'
			   EOF
 tags = {
    Name = "web-server"
  }
}

