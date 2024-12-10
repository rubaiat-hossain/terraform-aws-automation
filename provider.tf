terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    local = {
      source = "hashicorp/local"
    }
  }
}

# Configure the AWS Provider for us-east-1 (Node1 region)
provider "aws" {
  alias  = "east"
  region = "us-east-1"
}

# Configure the AWS Provider for us-west-1 (Node2 region)
provider "aws" {
  alias  = "west"
  region = "us-west-1"
}

# Configure the Local Provider
provider "local" {}
