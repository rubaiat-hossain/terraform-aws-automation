# TLS private key setup
resource "tls_private_key" "rsa" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

# Key pair setup for node1 (in us-east-1)
resource "aws_key_pair" "tf_key" {
  provider   = aws.east
  key_name   = "my-key-pair"
  public_key = tls_private_key.rsa.public_key_openssh
}

# Key pair setup for node2 (in us-west-1)
resource "aws_key_pair" "tf_key_node2" {
  provider   = aws.west
  key_name   = "my-key-pair-node2"
  public_key = tls_private_key.rsa.public_key_openssh
}

# Save private key to local file for node1
resource "local_file" "tf_key" {
  provider = local
  content  = tls_private_key.rsa.private_key_pem
  filename = "my-key-pair.pem"
}

# Save private key to local file for node2
resource "local_file" "tf_key_node2" {
  provider = local
  content  = tls_private_key.rsa.private_key_pem
  filename = "my-key-pair-node2.pem"
}

# VPC setup for node1 (in us-east-1)
resource "aws_vpc" "main_vpc" {
  provider = aws.east
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = "main_vpc"
  }
}

# Subnet setup for node1 (in us-east-1a)
resource "aws_subnet" "main_subnet" {
  provider = aws.east
  cidr_block        = "10.0.1.0/24"
  vpc_id            = aws_vpc.main_vpc.id
  availability_zone = "us-east-1a"

  depends_on = [
    aws_vpc.main_vpc
  ]
}

# Security group setup for node1 (in us-east-1)
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

# Internet gateway setup for node1 (in us-east-1)
resource "aws_internet_gateway" "main_gw" {
  provider = aws.east
  vpc_id = aws_vpc.main_vpc.id

  depends_on = [
    aws_vpc.main_vpc
  ]
}

# Route table setup for node1 (in us-east-1)
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

# Route table association for node1's subnet (us-east-1a)
resource "aws_route_table_association" "subnet_association" {
  provider      = aws.east
  subnet_id     = aws_subnet.main_subnet.id
  route_table_id = aws_route_table.main_route_table.id

  depends_on = [
    aws_route_table.main_route_table,
    aws_subnet.main_subnet
  ]
}

# AMI data lookup for node1 (in us-east-1)
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

# EC2 instance setup - node1 (in us-east-1a)
resource "aws_instance" "node1" {
  provider                    = aws.east
  ami                         = data.aws_ami.ubuntu_ami.id
  instance_type               = "t2.micro"
  key_name                    = aws_key_pair.tf_key.key_name
  vpc_security_group_ids      = [aws_security_group.allow_ssh_icmp_node1.id]  # Updated to include ICMP security group
  associate_public_ip_address = true
  subnet_id                   = aws_subnet.main_subnet.id

  tags = {
    Name = "node1"
  }

  depends_on = [
    aws_key_pair.tf_key,
    aws_vpc.main_vpc,
    aws_subnet.main_subnet,
    aws_security_group.allow_ssh_icmp_node1,  # Ensure the ICMP SG is created first
    aws_internet_gateway.main_gw,
    aws_route_table.main_route_table
  ]
}


# VPC setup for node2 (in us-west-1)
resource "aws_vpc" "main_vpc_node2" {
  provider = aws.west
  cidr_block           = "10.1.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = "main_vpc_node2"
  }
}

# Subnet setup for node2 (in us-west-1)
resource "aws_subnet" "main_subnet_node2" {
  provider = aws.west
  cidr_block        = "10.1.1.0/24"
  vpc_id            = aws_vpc.main_vpc_node2.id
  availability_zone = "us-west-1a"

  depends_on = [
    aws_vpc.main_vpc_node2
  ]
}

# Security group setup for node2 (in us-west-1)
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

# Internet gateway setup for node2 (in us-west-1)
resource "aws_internet_gateway" "main_gw_node2" {
  provider = aws.west
  vpc_id = aws_vpc.main_vpc_node2.id

  depends_on = [
    aws_vpc.main_vpc_node2
  ]
}

# Route table setup for node2 (in us-west-1)
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

# Route table association for node2's subnet (us-west-1a)
resource "aws_route_table_association" "subnet_association_node2" {
  provider      = aws.west
  subnet_id     = aws_subnet.main_subnet_node2.id
  route_table_id = aws_route_table.main_route_table_node2.id

  depends_on = [
    aws_route_table.main_route_table_node2,
    aws_subnet.main_subnet_node2
  ]
}

# AMI data lookup for node2 (in us-west-1)
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

# EC2 instance setup - node2 (in us-west-1a)
resource "aws_instance" "node2" {
  provider                    = aws.west
  ami                         = data.aws_ami.ubuntu_ami_node2.id
  instance_type               = "t2.micro"
  key_name                    = aws_key_pair.tf_key_node2.key_name
  vpc_security_group_ids      = [aws_security_group.allow_ssh_icmp_node2.id]  # Updated to include ICMP security group
  associate_public_ip_address = true
  subnet_id                   = aws_subnet.main_subnet_node2.id

  tags = {
    Name = "node2"
  }

  depends_on = [
    aws_key_pair.tf_key_node2,
    aws_vpc.main_vpc_node2,
    aws_subnet.main_subnet_node2,
    aws_security_group.allow_ssh_icmp_node2,  # Ensure the ICMP SG is created first
    aws_internet_gateway.main_gw_node2,
    aws_route_table.main_route_table_node2
  ]
}


# VPC peering connection from node1 to node2 (requester)
resource "aws_vpc_peering_connection" "vpc_peering_connection" {
  provider = aws.east
  vpc_id = aws_vpc.main_vpc.id
  peer_vpc_id = aws_vpc.main_vpc_node2.id
  peer_region = "us-west-1"

  auto_accept = false

  tags = {
    Name = "vpc-peering-connection"
  }
}

# VPC peering connection accepter (node2)
resource "aws_vpc_peering_connection_accepter" "accepter" {
  provider = aws.west
  vpc_peering_connection_id = aws_vpc_peering_connection.vpc_peering_connection.id
  auto_accept               = true

  tags = {
    Name = "vpc-peering-connection-accepter"
  }
}

# Route for node1 to node2 through peering
resource "aws_route" "node1_to_node2" {
  provider            = aws.east
  route_table_id      = aws_route_table.main_route_table.id
  destination_cidr_block = aws_vpc.main_vpc_node2.cidr_block
  vpc_peering_connection_id = aws_vpc_peering_connection.vpc_peering_connection.id
}

# Route for node2 to node1 through peering
resource "aws_route" "node2_to_node1" {
  provider            = aws.west
  route_table_id      = aws_route_table.main_route_table_node2.id
  destination_cidr_block = aws_vpc.main_vpc.cidr_block
  vpc_peering_connection_id = aws_vpc_peering_connection.vpc_peering_connection.id
}

# Security group for node1 allowing ICMP to node2
resource "aws_security_group" "allow_ssh_icmp_node1" {
  provider   = aws.east
  name       = "allow-ssh-icmp-node1"
  description = "Allow SSH and ICMP inbound traffic"
  vpc_id     = aws_vpc.main_vpc.id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = -1
    to_port     = -1
    protocol    = "icmp"
    cidr_blocks = ["10.1.1.0/24"]  # Node2 subnet CIDR block
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

# Security group for node2 allowing ICMP to node1
resource "aws_security_group" "allow_ssh_icmp_node2" {
  provider   = aws.west
  name       = "allow-ssh-icmp-node2"
  description = "Allow SSH and ICMP inbound traffic"
  vpc_id     = aws_vpc.main_vpc_node2.id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = -1
    to_port     = -1
    protocol    = "icmp"
    cidr_blocks = ["10.0.1.0/24"]  # Node1 subnet CIDR block
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


# Output for node1's private IP
output "node1_private_ip" {
  value = aws_instance.node1.private_ip
  description = "Private IP address of Node1"
}

# Output for node2's private IP
output "node2_private_ip" {
  value = aws_instance.node2.private_ip
  description = "Private IP address of Node2"
}

# Output EC2 instance public IP for node1
output "node1_public_ip" {
  value = aws_instance.node1.public_ip
}

# Output EC2 instance public IP for node2
output "node2_public_ip" {
  value = aws_instance.node2.public_ip
}

# Output key pair name for node1
output "node1_key_name" {
  value = aws_key_pair.tf_key.key_name
}

# Output key pair name for node2
output "node2_key_name" {
  value = aws_key_pair.tf_key_node2.key_name
}
