output "sitio" {
  description = "Dirección pública del CV."
  value       = module.static_site.url
}

output "api_url" {
  description = "Dirección de la API del contador."
  value       = module.counter_api.api_url
}

output "function_app_name" {
  description = "Nombre de la Function App; lo usa el paso del pipeline que sube el código."
  value       = module.counter_api.function_app_name
}

output "dashboard" {
  description = "Nombre del dashboard en Application Insights → Libros."
  value       = module.monitoring.dashboard_name
}
