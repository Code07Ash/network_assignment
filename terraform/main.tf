terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~>5.54.1"
    }
  }
}

provider "aws" {
  region = "eu-west-1"  # Ireland
}

resource "aws_key_pair" "my_key" {
  key_name   = "my-key"
  public_key = file("~/.ssh/id_rsa.pub")  # Path to your local public key
}

# 1. VPC
resource "aws_vpc" "my_vpc" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true

  tags = {
    Name = "MyCustomVPC"
  }
}

# 2. Internet Gateway
resource "aws_internet_gateway" "my_igw" {
  vpc_id = aws_vpc.my_vpc.id

  tags = {
    Name = "MyInternetGateway"
  }
}

# 3. Public Subnet (with Internet Access)
resource "aws_subnet" "my_public_subnet" {
  vpc_id                  = aws_vpc.my_vpc.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "eu-west-1a"
  map_public_ip_on_launch = true

  tags = {
    Name = "MyPublicSubnet"
  }
}

# 4. Private Subnet (without direct internet access)
resource "aws_subnet" "my_private_subnet" {
  vpc_id                  = aws_vpc.my_vpc.id
  cidr_block              = "10.0.2.0/24"
  availability_zone       = "eu-west-1a"
  map_public_ip_on_launch = false

  tags = {
    Name = "MyPrivateSubnet"
  }
}

# 5. Route Table for Public Subnet
resource "aws_route_table" "my_public_route_table" {
  vpc_id = aws_vpc.my_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.my_igw.id
  }

  tags = {
    Name = "MyPublicRouteTable"
  }
}

# 6. Route Table for Private Subnet (no internet access directly)
resource "aws_route_table" "my_private_route_table" {
  vpc_id = aws_vpc.my_vpc.id

  tags = {
    Name = "MyPrivateRouteTable"
  }
}

# 7. Associate Route Table with Public Subnet
resource "aws_route_table_association" "my_public_rt_assoc" {
  subnet_id      = aws_subnet.my_public_subnet.id
  route_table_id = aws_route_table.my_public_route_table.id
}

# 8. Associate Route Table with Private Subnet (no route to Internet Gateway)
resource "aws_route_table_association" "my_private_rt_assoc" {
  subnet_id      = aws_subnet.my_private_subnet.id
  route_table_id = aws_route_table.my_private_route_table.id
}

# 9. Security Group - Allow HTTP (for public-facing EC2)
resource "aws_security_group" "allow_http" {
  name        = "allow_http"
  description = "Allow HTTP access"
  vpc_id      = aws_vpc.my_vpc.id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    from_port   = 22
    to_port     = 22
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
    Name = "HTTPAccessSG"
  }
}

# 10. EC2 Instance in Public Subnet (no key pair, HTTP access)
resource "aws_instance" "my_ec2" {
  ami                    = "ami-0df368112825f8d8f"  # Ensure this AMI is correct for eu-west-1
  instance_type          = "t2.micro"
  subnet_id              = aws_subnet.my_public_subnet.id
  vpc_security_group_ids = [aws_security_group.allow_http.id]
  key_name               = "my-key"
  associate_public_ip_address = true

  tags = {
    Name = "EC2-In-Public-Subnet"
  }
}




