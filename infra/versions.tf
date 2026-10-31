terraform {
  required_version = ">= 1.10"

  cloud {
    organization = "meetings_ooad"

    workspaces {
      name = "meetings-dev"
    }
  }

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
    http = {
      source  = "hashicorp/http"
      version = "~> 3.4"
    }
  }
}

provider "aws" {
  region = var.region

  # Every resource that accepts tags gets PROJECT_NAME (the course rule), without repeating it.
  default_tags {
    tags = {
      PROJECT_NAME = var.project_name
    }
  }
}
