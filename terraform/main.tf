provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Environment = var.environment
      Project     = "eks-gitops-platform"
      ManagedBy   = "terraform"
    }
  }
}

data "aws_availability_zones" "available" {
  state = "available"
}

locals {
  azs = slice(data.aws_availability_zones.available.names, 0, 3)

  common_tags = {
    Terraform   = "true"
    Environment = var.environment
    Project     = var.cluster_name
  }

  eks_shared_tags = {
    "kubernetes.io/cluster/${var.cluster_name}" = "shared"
  }
}
