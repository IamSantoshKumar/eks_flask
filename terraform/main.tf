# ------------------------------------------
# 5. terraform/main.tf (EKS infra with VPC, public subnets, IGW, routes, and ECR)
# ------------------------------------------

provider "aws" {
  region = "eu-north-1"
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
  availability_zone       = "eu-north-1a"
  map_public_ip_on_launch = true
  tags = {
    Name = "flask-eks-public-subnet-1"
  }
}

resource "aws_subnet" "public_subnet_2" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.2.0/24"
  availability_zone       = "eu-north-1b"
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

module "eks" {
  source          = "terraform-aws-modules/eks/aws"
  cluster_name    = "flask-eks-cluster"
  cluster_version = "1.29"
  subnet_ids = [
    aws_subnet.public_subnet_1.id,
    aws_subnet.public_subnet_2.id
  ]
  vpc_id = aws_vpc.main.id
  cluster_endpoint_public_access = true
  cluster_endpoint_private_access = true

  eks_managed_node_group_defaults = {
    instance_types = ["t3.micro"]
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

resource "aws_security_group_rule" "eks_api_ingress" {
  type              = "ingress"
  from_port         = 443
  to_port           = 443
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = module.eks.cluster_security_group_id
  description       = "Allow public access to EKS API from anywhere"
}