variable "github_runner_token" {
  type      = string
  sensitive = true
}
############################
# VPC
############################

resource "aws_vpc" "main_vpc" {

  cidr_block       = "10.0.0.0/16"
  instance_tenancy = "default"

  tags = {
    Name = "github-runner-vpc"
  }
}

############################
# INTERNET GATEWAY
############################

resource "aws_internet_gateway" "igw" {

  vpc_id = aws_vpc.main_vpc.id

  tags = {
    Name = "github-runner-igw"
  }
}

############################
# PUBLIC SUBNET A
############################

resource "aws_subnet" "public_subnet_a" {

  vpc_id            = aws_vpc.main_vpc.id
  cidr_block        = "10.0.1.0/24"
  availability_zone = "ap-south-1a"

  tags = {
    Name = "public-subnet-a"
  }
}

############################
# PUBLIC SUBNET B
############################

resource "aws_subnet" "public_subnet_b" {

  vpc_id            = aws_vpc.main_vpc.id
  cidr_block        = "10.0.2.0/24"
  availability_zone = "ap-south-1b"

  tags = {
    Name = "public-subnet-b"
  }
}

############################
# PRIVATE SUBNET A
############################

resource "aws_subnet" "private_subnet_a" {

  vpc_id            = aws_vpc.main_vpc.id
  cidr_block        = "10.0.11.0/24"
  availability_zone = "ap-south-1a"

  tags = {
    Name = "private-subnet-a"
  }
}

############################
# PRIVATE SUBNET B
############################

resource "aws_subnet" "private_subnet_b" {

  vpc_id            = aws_vpc.main_vpc.id
  cidr_block        = "10.0.12.0/24"
  availability_zone = "ap-south-1b"

  tags = {
    Name = "private-subnet-b"
  }
}

############################
# ELASTIC IP
############################

resource "aws_eip" "nat_eip" {

  domain = "vpc"
}

############################
# NAT GATEWAY
############################

resource "aws_nat_gateway" "nat" {

  allocation_id = aws_eip.nat_eip.id

  subnet_id = aws_subnet.public_subnet_a.id

  depends_on = [aws_internet_gateway.igw]

  tags = {
    Name = "nat-gateway"
  }
}

############################
# PUBLIC ROUTE TABLE
############################

resource "aws_route_table" "public_rt" {

  vpc_id = aws_vpc.main_vpc.id

  tags = {
    Name = "public-route-table"
  }
}

resource "aws_route" "public_route" {

  route_table_id = aws_route_table.public_rt.id

  destination_cidr_block = "0.0.0.0/0"

  gateway_id = aws_internet_gateway.igw.id
}

############################
# PRIVATE ROUTE TABLE
############################

resource "aws_route_table" "private_rt" {

  vpc_id = aws_vpc.main_vpc.id

  tags = {
    Name = "private-route-table"
  }
}

resource "aws_route" "private_route" {

  route_table_id = aws_route_table.private_rt.id

  destination_cidr_block = "0.0.0.0/0"

  nat_gateway_id = aws_nat_gateway.nat.id
}

############################
# ROUTE TABLE ASSOCIATIONS
############################

resource "aws_route_table_association" "public_assoc_a" {

  subnet_id = aws_subnet.public_subnet_a.id

  route_table_id = aws_route_table.public_rt.id
}

resource "aws_route_table_association" "public_assoc_b" {

  subnet_id = aws_subnet.public_subnet_b.id

  route_table_id = aws_route_table.public_rt.id
}

resource "aws_route_table_association" "private_assoc_a" {

  subnet_id = aws_subnet.private_subnet_a.id

  route_table_id = aws_route_table.private_rt.id
}

resource "aws_route_table_association" "private_assoc_b" {

  subnet_id = aws_subnet.private_subnet_b.id

  route_table_id = aws_route_table.private_rt.id
}

############################
# SECURITY GROUP
############################

resource "aws_security_group" "runner_sg" {

  name = "github-runner-sg"

  vpc_id = aws_vpc.main_vpc.id

  egress {

    from_port = 0

    to_port = 0

    protocol = "-1"

    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "github-runner-sg"
  }
}

############################
# IAM ROLE
############################

resource "aws_iam_role" "runner_role" {

  name = "github-runner-role"

  assume_role_policy = jsonencode({

    Version = "2012-10-17"

    Statement = [

      {

        Effect = "Allow"

        Principal = {

          Service = "ec2.amazonaws.com"
        }

        Action = "sts:AssumeRole"
      }
    ]
  })
}

############################
# S3 FULL ACCESS POLICY
############################

resource "aws_iam_role_policy_attachment" "s3" {

  role = aws_iam_role.runner_role.name

  policy_arn = "arn:aws:iam::aws:policy/AmazonS3FullAccess"
}
resource "aws_iam_role_policy_attachment" "ssm" {

  role = aws_iam_role.runner_role.name

  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}
############################
# INSTANCE PROFILE
############################

resource "aws_iam_instance_profile" "runner_profile" {

  name = "github-runner-profile"

  role = aws_iam_role.runner_role.name
}

############################
# GITHUB RUNNER EC2
############################

resource "aws_instance" "github_runner" {

  ami = "ami-0388e3ada3d9812da"

  instance_type = "t3.micro"

  subnet_id = aws_subnet.private_subnet_a.id

  vpc_security_group_ids = [
    aws_security_group.runner_sg.id
  ]

  iam_instance_profile = aws_iam_instance_profile.runner_profile.name

  user_data = <<-EOF
#!/bin/bash
set -e

export RUNNER_ALLOW_RUNASROOT=1

apt update -y
apt install -y curl wget unzip

mkdir -p /actions-runner
cd /actions-runner

curl -o actions-runner.tar.gz -L https://github.com/actions/runner/releases/download/v2.328.0/actions-runner-linux-x64-2.328.0.tar.gz

tar xzf actions-runner.tar.gz

./config.sh \
--url https://github.com/Mehak-gupta23/github-actions-final \
--token ${var.github_runner_token} \
--unattended \
--name github-runner \
--replace

./run.sh
EOF

  tags = {
    Name = "github-runner"
  }
}
