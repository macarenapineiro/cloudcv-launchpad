output "resource_group_name" {
  value = azurerm_resource_group.tfstate.name
}

output "storage_account_name" {
  value = azurerm_storage_account.tfstate.name
}

output "container_name" {
  value = azurerm_storage_container.tfstate.name
}

output "github_client_id" {
  value = azurerm_user_assigned_identity.github.client_id
}

output "tenant_id" {
  value = azurerm_user_assigned_identity.github.tenant_id
}

output "subscription_id" {
  value = var.subscription_id
}