terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.51.0"
    }
    docker = {
      source  = "kreuzwerker/docker"
      version = "~> 4.4.0"
    }
  }

  required_version = ">= 1.15"
}

provider "aws" {
  region = var.aws_region
}

provider "docker" {
  // host = "unix:///var/run/docker.sock" // Update to use another host
}
