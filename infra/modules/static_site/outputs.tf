output "url" {
  description = "Dirección pública del sitio (con HTTPS)."
  value       = azurerm_storage_account.sitio.primary_web_endpoint
}

output "origen" {
  description = "Origen del sitio sin la barra final; lo usa la Function para configurar CORS."
  value       = trimsuffix(azurerm_storage_account.sitio.primary_web_endpoint, "/")
}

output "storage_account_name" {
  description = "Nombre de la cuenta de Storage del sitio."
  value       = azurerm_storage_account.sitio.name
}
