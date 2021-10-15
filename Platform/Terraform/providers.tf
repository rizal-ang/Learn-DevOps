terraform {
  backend "azurerm" {}
  required_providers {
    databricks = {
      source = "databrickslabs/databricks"    
    }
  }
}

provider "databricks" {}
provider "azurerm" {
  features {}
}