output "dashboard_name" {
  description = "Nombre visible del dashboard (workbook) en el portal."
  value       = azurerm_application_insights_workbook.dashboard.display_name
}

output "alert_name" {
  description = "Nombre de la alerta de errores."
  value       = azurerm_monitor_scheduled_query_rules_alert_v2.errores.name
}

output "action_group_id" {
  description = "ID del grupo de aviso (se puede reutilizar para otras alertas)."
  value       = azurerm_monitor_action_group.equipo.id
}
