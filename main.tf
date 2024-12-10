# TLS Private Key Setup
resource "tls_private_key" "rsa" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

# Key Pair Setup for Node1 (In us-east-1)
resource "aws_key_pair" "tf_key" {
  provider   = aws.east
  key_name   = "my-key-pair"
  public_key = tls_private_key.rsa.public_key_openssh
}

# Key Pair Setup for Node2 (In us-west-1)
resource "aws_key_pair" "tf_key_node2" {
  provider   = aws.west
  key_name   = "my-key-pair-node2"
  public_key = tls_private_key.rsa.public_key_openssh
}

# Save Private Key to Local File for Node1
resource "local_file" "tf_key" {
  provider = local
  content  = tls_private_key.rsa.private_key_pem
  filename = "my-key-pair.pem"  # You can specify a different filename if needed
}

# Save Private Key to Local File for Node2
resource "local_file" "tf_key_node2" {
  provider = local
  content  = tls_private_key.rsa.private_key_pem
  filename = "my-key-pair-node2.pem"  # A different file for node2, if needed
}

# VPC Setup for Node1 (In us-east-1)
resource "aws_vpc" "main_vpc" {
  provider = aws.east
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = "main_vpc"
  }
 
}

# Subnet Setup for Node1 (Availability Zone: us-east-1a)
resource "aws_subnet" "main_subnet" {
  provider = aws.east
  cidr_block        = "10.0.1.0/24"
  vpc_id            = aws_vpc.main_vpc.id
  availability_zone = "us-east-1a"

  depends_on = [
    aws_vpc.main_vpc
  ]
}

# Security Group Setup for Node1 (In us-east-1)
resource "aws_security_group" "allow_ssh" {
  provider   = aws.east
  name       = "allow-ssh"
  description = "Allow SSH inbound traffic"
  vpc_id     = aws_vpc.main_vpc.id

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

  depends_on = [
    aws_vpc.main_vpc
  ]
}

# Internet Gateway Setup for Node1 (In us-east-1)
resource "aws_internet_gateway" "main_gw" {
  provider = aws.east
  vpc_id = aws_vpc.main_vpc.id

  depends_on = [
    aws_vpc.main_vpc
  ]
}

# Route Table Setup for Node1 (In us-east-1)
resource "aws_route_table" "main_route_table" {
  provider = aws.east
  vpc_id = aws_vpc.main_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main_gw.id
  }

  depends_on = [
    aws_internet_gateway.main_gw,
    aws_vpc.main_vpc
  ]
}

# Route Table Association for Node1's Subnet (us-east-1a)
resource "aws_route_table_association" "subnet_association" {
  provider      = aws.east
  subnet_id     = aws_subnet.main_subnet.id
  route_table_id = aws_route_table.main_route_table.id

  depends_on = [
    aws_route_table.main_route_table,
    aws_subnet.main_subnet
  ]
}

# AMI Data Lookup for Node1 (In us-east-1)
data "aws_ami" "ubuntu_ami" {
  provider = aws.east
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
  provider                    = aws.east
  ami                         = data.aws_ami.ubuntu_ami.id
  instance_type               = "t2.micro"
  key_name                    = aws_key_pair.tf_key.key_name
  vpc_security_group_ids      = [aws_security_group.allow_ssh.id]
  associate_public_ip_address = true
  subnet_id                   = aws_subnet.main_subnet.id

  tags = {
    Name = "node1"
  }

  depends_on = [
    aws_key_pair.tf_key,
    aws_vpc.main_vpc,
    aws_subnet.main_subnet,
    aws_security_group.allow_ssh,
    aws_internet_gateway.main_gw,
    aws_route_table.main_route_table
  ]
}

# VPC Setup for Node2 (In us-west-1)
resource "aws_vpc" "main_vpc_node2" {
  provider = aws.west
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = "main_vpc_node2"
  }
}

# Subnet Setup for Node2 (In us-west-1)
resource "aws_subnet" "main_subnet_node2" {
  provider = aws.west
  cidr_block        = "10.0.1.0/24"
  vpc_id            = aws_vpc.main_vpc_node2.id
  availability_zone = "us-west-1a"

  depends_on = [
    aws_vpc.main_vpc_node2
  ]
}

# Security Group Setup for Node2 (In us-west-1)
resource "aws_security_group" "allow_ssh_node2" {
  provider   = aws.west
  name       = "allow-ssh-node2"
  description = "Allow SSH inbound traffic"
  vpc_id     = aws_vpc.main_vpc_node2.id

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

  depends_on = [
    aws_vpc.main_vpc_node2
  ]
}

# Internet Gateway Setup for Node2 (In us-west-1)
resource "aws_internet_gateway" "main_gw_node2" {
  provider = aws.west
  vpc_id = aws_vpc.main_vpc_node2.id

  depends_on = [
    aws_vpc.main_vpc_node2
  ]
}

# Route Table Setup for Node2 (In us-west-1)
resource "aws_route_table" "main_route_table_node2" {
  provider = aws.west
  vpc_id = aws_vpc.main_vpc_node2.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main_gw_node2.id
  }

  depends_on = [
    aws_internet_gateway.main_gw_node2,
    aws_vpc.main_vpc_node2
  ]
}

# Route Table Association for Node2's Subnet (us-west-1a)
resource "aws_route_table_association" "subnet_association_node2" {
  provider      = aws.west
  subnet_id     = aws_subnet.main_subnet_node2.id
  route_table_id = aws_route_table.main_route_table_node2.id

  depends_on = [
    aws_route_table.main_route_table_node2,
    aws_subnet.main_subnet_node2
  ]
}

# AMI Data Lookup for Node2 (In us-west-1)
data "aws_ami" "ubuntu_ami_node2" {
  provider = aws.west
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

# EC2 Instance Setup - Node2 (In us-west-1a)
resource "aws_instance" "node2" {
  provider                    = aws.west
  ami                         = data.aws_ami.ubuntu_ami_node2.id
  instance_type               = "t2.micro"
  key_name                    = aws_key_pair.tf_key_node2.key_name
  vpc_security_group_ids      = [aws_security_group.allow_ssh_node2.id]
  associate_public_ip_address = true
  subnet_id                   = aws_subnet.main_subnet_node2.id

  tags = {
    Name = "node2"
  }

  depends_on = [
    aws_key_pair.tf_key_node2,
    aws_vpc.main_vpc_node2,
    aws_subnet.main_subnet_node2,
    aws_security_group.allow_ssh_node2,
    aws_internet_gateway.main_gw_node2,
    aws_route_table.main_route_table_node2
  ]
}

# Output for Key Pair & Instance IP
output "instance_public_ip_node1" {
  value = aws_instance.node1.public_ip
}

output "instance_public_ip_node2" {
  value = aws_instance.node2.public_ip
}


# Output Key Pair Path
output "key_pair_path_node1" {
  value = local_file.tf_key.filename
}

output "key_pair_path_node2" {
  value = local_file.tf_key_node2.filename
}

