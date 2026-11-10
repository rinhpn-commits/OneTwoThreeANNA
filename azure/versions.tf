terraform {
  required_version = ">= 1.10"

  cloud {
    organization = "meetings_ooad"
    workspaces {
      name = "meetings-azure"
    }
  }

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
  }
}

provider "azurerm" {
  resource_provider_registrations = "none"
  features {}
}
