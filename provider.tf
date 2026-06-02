terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "6.46.0"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "4.3.0"
    }
  }
  backend "s3" {
    bucket  = "mys3-bucket-sdp"
    key     = "vpc/terraform.tfstate"
    region  = "us-east-1"
    encrypt = true
  }
}



provider "aws" {

  default_tags {
    tags = {
      Environment = "development"
      CreatedBy   = "terraform"
    }
  }
}