# TLS Private Key Setup
resource "tls_private_key" "rsa" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

# Key Pair Setup
resource "aws_key_pair" "tf_key" {
  key_name   = "my-key-pair"
  public_key = tls_private_key.rsa.public_key_openssh
}

# Save Private Key to Local File
resource "local_file" "tf_key" {
  content  = tls_private_key.rsa.private_key_pem
  filename = "my-key-pair.pem"  # You can specify a different filename if needed
}

# VPC Setup
resource "aws_vpc" "main_vpc" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = "main_vpc"
  }
}

# Subnet Setup for Node1 (Availability Zone: us-east-1a)
resource "aws_subnet" "main_subnet" {
  cidr_block        = "10.0.1.0/24"
  vpc_id            = aws_vpc.main_vpc.id
  availability_zone = "us-east-1a"
}

# Subnet Setup for Node2 (Availability Zone: us-east-1b)
resource "aws_subnet" "main_subnet_node2" {
  cidr_block        = "10.0.2.0/24"
  vpc_id            = aws_vpc.main_vpc.id
  availability_zone = "us-east-1b"  # Change availability zone for node2
}

# Security Group Setup
resource "aws_security_group" "allow_ssh" {
  name        = "allow-ssh"
  description = "Allow SSH inbound traffic"
  vpc_id      = aws_vpc.main_vpc.id

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
}

# Internet Gateway Setup
resource "aws_internet_gateway" "main_gw" {
  vpc_id = aws_vpc.main_vpc.id
}

# Route Table Setup
resource "aws_route_table" "main_route_table" {
  vpc_id = aws_vpc.main_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main_gw.id
  }
}

# Route Table Association for Node1's Subnet (us-east-1a)
resource "aws_route_table_association" "subnet_association" {
  subnet_id      = aws_subnet.main_subnet.id
  route_table_id = aws_route_table.main_route_table.id
}

# Route Table Association for Node2's Subnet (us-east-1b) - Add this to ensure node2 is in the route
resource "aws_route_table_association" "subnet_association_node2" {
  subnet_id      = aws_subnet.main_subnet_node2.id
  route_table_id = aws_route_table.main_route_table.id
}

# AMI Data Lookup
data "aws_ami" "ubuntu_ami" {
  most_recent = true

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-focal-20.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  owners = ["099720109477"]
}

# EC2 Instance Setup - Node1 (In us-east-1a)
resource "aws_instance" "node1" {
  ami                         = data.aws_ami.ubuntu_ami.id
  instance_type               = "t2.micro"
  key_name                    = aws_key_pair.tf_key.key_name
  vpc_security_group_ids      = [aws_security_group.allow_ssh.id]  # Use vpc_security_group_ids instead of security_groups
  associate_public_ip_address = true
  subnet_id                   = aws_subnet.main_subnet.id  # Use the subnet from us-east-1a

  tags = {
    Name = "node1"
  }
}

# EC2 Instance Setup - Node2 (In us-east-1b)
resource "aws_instance" "node2" {
  ami                         = data.aws_ami.ubuntu_ami.id
  instance_type               = "t2.micro"
  key_name                    = aws_key_pair.tf_key.key_name
  vpc_security_group_ids      = [aws_security_group.allow_ssh.id]
  associate_public_ip_address = true
  subnet_id                   = aws_subnet.main_subnet_node2.id  # Use the subnet from us-east-1b

  tags = {
    Name = "node2"
  }
}

# Output IPs for node1
output "instance_private_ip_node1" {
  value = aws_instance.node1.private_ip
}

output "instance_public_ip_node1" {
  value = aws_instance.node1.public_ip
}

# Output IPs for node2
output "instance_private_ip_node2" {
  value = aws_instance.node2.private_ip
}

output "instance_public_ip_node2" {
  value = aws_instance.node2.public_ip
}

# Output Key Pair Path
output "key_pair_file" {
  value = local_file.tf_key.filename
}
