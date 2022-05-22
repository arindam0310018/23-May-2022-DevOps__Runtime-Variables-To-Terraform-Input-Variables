terraform {
  required_version = ">= 1.2.0"

   backend "azurerm" {
    resource_group_name  = "tfpipeline-rg"
    storage_account_name = "tfpipelinesa"
    container_name       = "terraform"
    key                  = "UMID/usrmid.tfstate"
  }
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.2"
    }   
  }
}
provider "azurerm" {
  features {}
  skip_provider_registration = true
}