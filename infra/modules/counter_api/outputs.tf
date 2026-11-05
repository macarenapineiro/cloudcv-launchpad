output "function_app_name" {
  description = "Nombre de la Function App (se usa para subir el código)."
  value       = azurerm_function_app_flex_consumption.contador.name
}

output "api_url" {
  description = "Dirección completa de la API del contador; va en API_URL de script.js."
  value       = "https://${azurerm_function_app_flex_consumption.contador.default_hostname}/api/visitas"
}

output "principal_id" {
  description = "ID de la identidad de la Function (para la matriz IAM)."
  value       = azurerm_function_app_flex_consumption.contador.identity[0].principal_id
}

output "application_insights_id" {
  description = "ID de Application Insights; lo usa el dashboard y la alarma."
  value       = azurerm_application_insights.insights.id
}

output "log_analytics_workspace_id" {
  description = "ID del workspace de logs."
  value       = azurerm_log_analytics_workspace.logs.id
}
