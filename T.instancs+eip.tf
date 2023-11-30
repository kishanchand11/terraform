#creating instance and attaching eip via providing instanceid


terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.16"
    }
  }

  required_version = ">= 1.2.0"
}

provider "aws" {
  region  = "us-east-2"
}

resource "aws_instance" "assignment2" {
  ami           = "ami-024e6efaf93d85776"
  instance_type = "t2.micro"

  tags = {
    Name = "assignment3"
  }
}
resource "aws_eip" "eg-eip" {
  vpc = true
  instance = aws_instance.assignment2.id
}
