# ── A quién avisar ─────────────────────────────────────────────────────────────
# Un "action group" es la lista de a quién avisa Azure cuando se dispara una alerta.
resource "azurerm_monitor_action_group" "equipo" {
  name                = "ag-${var.prefix}-equipo"
  resource_group_name = var.resource_group_name
  short_name          = "${var.prefix}team" # máximo 12 caracteres: aparece en el SMS/mail

  dynamic "email_receiver" {
    for_each = var.alert_emails
    content {
      name                    = "mail-${email_receiver.key}"
      email_address           = email_receiver.value
      use_common_alert_schema = true
    }
  }

  tags = var.tags
}

# ── Alerta: demasiados errores ─────────────────────────────────────────────────
# Cada 5 minutos mira las llamadas a la API de los últimos 5 minutos.
# Si más del X % respondió con error 5xx, avisa por mail. Cuando se arregla, avisa de nuevo.
resource "azurerm_monitor_scheduled_query_rules_alert_v2" "errores" {
  name                = "alert-${var.prefix}-errores"
  resource_group_name = var.resource_group_name
  location            = var.location
  description         = "Más del ${var.error_rate_threshold} % de las llamadas al contador fallaron (5xx) en 5 minutos."
  severity            = 1 # 0 = crítica ... 4 = informativa

  scopes               = [var.application_insights_id]
  evaluation_frequency = "PT5M"
  window_duration      = "PT5M"

  criteria {
    query = <<-KQL
      requests
      | summarize total = count(), errores = countif(toint(resultCode) >= 500)
      | extend tasa = 100.0 * errores / total
      | where total > 0 and tasa > ${var.error_rate_threshold}
    KQL

    # La consulta solo devuelve una fila cuando se supera el umbral: si hay filas, se dispara.
    time_aggregation_method = "Count"
    operator                = "GreaterThan"
    threshold               = 0

    failing_periods {
      minimum_failing_periods_to_trigger_alert = 1
      number_of_evaluation_periods             = 1
    }
  }

  auto_mitigation_enabled = true # se cierra sola cuando los errores bajan

  action {
    action_groups = [azurerm_monitor_action_group.equipo.id]
  }

  tags = var.tags
}

# ── Dashboard ──────────────────────────────────────────────────────────────────
# Un "workbook" de Azure Monitor: una página con gráficas armadas con consultas sobre
# los datos que la Function manda a Application Insights. Solo métricas nativas.
resource "random_uuid" "dashboard" {}

locals {
  # Gráficas de las últimas 24 horas, agrupadas cada 5 minutos.
  ultimas_24h = { durationMs = 86400000 }

  graficas = [
    {
      titulo = "Visitas (llamadas a la API)"
      tipo   = "timechart"
      kql    = "requests\n| summarize Visitas = count() by bin(timestamp, 5m)"
    },
    {
      titulo = "Errores (respuestas 5xx)"
      tipo   = "timechart"
      kql    = "requests\n| summarize Errores = countif(toint(resultCode) >= 500), Total = count() by bin(timestamp, 5m)"
    },
    {
      titulo = "Latencia p95 (milisegundos)"
      tipo   = "timechart"
      kql    = "requests\n| summarize p95 = percentile(duration, 95) by bin(timestamp, 5m)"
    },
    {
      titulo = "Resumen de las últimas 24 horas"
      tipo   = "table"
      kql    = "requests\n| summarize Visitas = count(), Errores = countif(toint(resultCode) >= 500), ['Latencia p95 (ms)'] = round(percentile(duration, 95), 0)"
    },
  ]
}

resource "azurerm_application_insights_workbook" "dashboard" {
  name                = random_uuid.dashboard.result # Azure exige que el nombre sea un UUID
  resource_group_name = var.resource_group_name
  location            = var.location
  display_name        = "CloudCV - Contador de visitas"
  source_id           = lower(var.application_insights_id)

  data_json = jsonencode({
    version = "Notebook/1.0"
    items = concat(
      [{
        type    = 1
        name    = "titulo"
        content = { json = "## CloudCV - Contador de visitas\nLlamadas a la API, errores y latencia de la Function. Últimas 24 horas." }
      }],
      [for i, g in local.graficas : {
        type = 3
        name = "grafica-${i}"
        content = {
          version       = "KqlItem/1.0"
          query         = g.kql
          size          = 0
          title         = g.titulo
          timeContext   = local.ultimas_24h
          queryType     = 0
          resourceType  = "microsoft.insights/components"
          visualization = g.tipo
        }
      }]
    )
    fallbackResourceIds = [lower(var.application_insights_id)]
    "$schema"           = "https://github.com/Microsoft/Application-Insights-Workbooks/blob/master/schema/workbook.json"
  })

  tags = var.tags
}
