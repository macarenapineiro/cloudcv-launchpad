output "storage_account_name" {
  description = "Nombre de la cuenta de Storage de datos."
  value       = azurerm_storage_account.datos.name
}

output "table_name" {
  description = "Nombre de la tabla del contador."
  value       = azapi_resource.visitas.name
}

output "table_endpoint" {
  description = "Dirección del servicio de tablas; la Function la usa para conectarse."
  value       = azurerm_storage_account.datos.primary_table_endpoint
}

output "table_id" {
  description = "ID de la tabla en Azure; se usa para darle permiso a la Function solo sobre esta tabla."
  value       = azapi_resource.visitas.id
}
