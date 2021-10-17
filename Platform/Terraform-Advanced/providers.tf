terraform {
  backend "local" {}
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "=2.46.0"
    }
    databricks = {
      source = "databrickslabs/databricks"    
    }
  }
}

provider "databricks" {}
provider "azurerm" {
  features {}
}