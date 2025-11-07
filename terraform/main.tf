terraform {
  required_version = ">= 1.0"
  
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.0"
    }
  }

  backend "azurerm" {
    # Backend configuration should be provided via backend config file or command line
    # Example: terraform init -backend-config="backend.hcl"
  }
}

provider "azurerm" {
  features {}
}
