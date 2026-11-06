terraform {
  backend "azurerm" {
    resource_group_name  = "rg-cloudcv-tfstate"
    storage_account_name = "cloudcvtfstate0oxp"
    container_name       = "tfstate"
    key                  = "dev.tfstate"
    use_azuread_auth     = true
  }
}