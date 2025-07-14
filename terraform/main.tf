# ------------------------------------------
# 5. terraform/main.tf (EKS infra with VPC, public subnets, IGW, routes, and ECR)
# ------------------------------------------

provider "aws" {
  region = "us-east-1"
}

resource "aws_vpc" "main" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags = {
    Name = "flask-eks-vpc"
  }
}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id
  tags = {
    Name = "flask-eks-igw"
  }
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }
  tags = {
    Name = "flask-eks-public-rt"
  }
}

resource "aws_subnet" "public_subnet_1" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "us-east-1a"
  map_public_ip_on_launch = true
  tags = {
    Name = "flask-eks-public-subnet-1"
  }
}

resource "aws_subnet" "public_subnet_2" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.2.0/24"
  availability_zone       = "us-east-1b"
  map_public_ip_on_launch = true
  tags = {
    Name = "flask-eks-public-subnet-2"
  }
}

resource "aws_route_table_association" "public_1" {
  subnet_id      = aws_subnet.public_subnet_1.id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "public_2" {
  subnet_id      = aws_subnet.public_subnet_2.id
  route_table_id = aws_route_table.public.id
}

resource "aws_ecr_repository" "flask_repo" {
  name = "flask-hello-world"
}

output "repository_url" {
  value = aws_ecr_repository.flask_repo.repository_url
}

output "public_ip_addresses" {
  description = "Public IPs of worker nodes"
  value = module.eks.eks_managed_node_groups[*].public_ip
}

module "eks" {
  source          = "terraform-aws-modules/eks/aws"
  cluster_name    = "flask-eks-cluster"
  cluster_version = "1.29"
  subnet_ids = [
    aws_subnet.public_subnet_1.id,
    aws_subnet.public_subnet_2.id
  ]
  vpc_id = aws_vpc.main.id

  eks_managed_node_group_defaults = {
    instance_types = ["t3.medium"]
  }

  eks_managed_node_groups = {
    default_node_group = {
      desired_size = 2
      max_size     = 2
      min_size     = 2
      name         = "ng-flask"
    }
  }
}