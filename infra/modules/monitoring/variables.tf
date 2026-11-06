variable "resource_group_name" {
  description = "Nombre del resource group donde se crean el dashboard y la alerta."
  type        = string
}

variable "location" {
  description = "Región de Azure (la misma que Application Insights)."
  type        = string

  validation {
    condition     = contains(["chilecentral", "mexicocentral", "canadacentral", "northcentralus", "brazilsouth"], var.location)
    error_message = "La región tiene que ser una de las permitidas por la suscripción Azure for Students."
  }
}

variable "prefix" {
  description = "Prefijo para los nombres de los recursos (solo minúsculas y números)."
  type        = string
  default     = "cloudcv"

  validation {
    condition     = can(regex("^[a-z0-9]{3,12}$", var.prefix))
    error_message = "El prefijo tiene que tener entre 3 y 12 letras minúsculas o números, sin guiones."
  }
}

variable "application_insights_id" {
  description = "ID de Application Insights de la Function (sale del módulo counter_api)."
  type        = string
}

variable "alert_emails" {
  description = "Mails que reciben el aviso cuando se dispara la alerta."
  type        = list(string)

  validation {
    condition     = length(var.alert_emails) > 0 && alltrue([for m in var.alert_emails : can(regex("^[^@ ]+@[^@ ]+\\.[^@ ]+$", m))])
    error_message = "Tiene que haber al menos un mail y todos tienen que ser válidos."
  }
}

variable "error_rate_threshold" {
  description = "Porcentaje de llamadas con error (5xx) en 5 minutos a partir del cual se dispara la alerta."
  type        = number
  default     = 5

  validation {
    condition     = var.error_rate_threshold > 0 && var.error_rate_threshold <= 100
    error_message = "Tiene que ser un porcentaje entre 0 y 100."
  }
}

variable "tags" {
  description = "Etiquetas obligatorias: project, team, env y owner."
  type        = map(string)

  validation {
    condition     = alltrue([for t in ["project", "team", "env", "owner"] : contains(keys(var.tags), t)])
    error_message = "Faltan etiquetas: tienen que estar project, team, env y owner."
  }
}
