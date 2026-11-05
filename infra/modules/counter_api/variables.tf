variable "resource_group_name" {
  description = "Nombre del resource group donde se crea la Function."
  type        = string
}

variable "location" {
  description = "Región de Azure donde se crea la Function."
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

variable "allowed_origin" {
  description = "Dirección del sitio del CV (sin barra final). Es el único origen que puede llamar a la Function desde el navegador (CORS)."
  type        = string

  validation {
    condition     = can(regex("^https://[^/]+$", var.allowed_origin))
    error_message = "Tiene que empezar con https:// y no terminar con barra, por ejemplo https://cloudcvwebabc123.z9.web.core.windows.net"
  }
}

variable "table_id" {
  description = "ID de la tabla del contador (sale del módulo database). Se usa para darle permiso a la Function solo sobre esa tabla."
  type        = string
}

variable "table_endpoint" {
  description = "Dirección del servicio de tablas (sale del módulo database)."
  type        = string
}

variable "table_name" {
  description = "Nombre de la tabla del contador (sale del módulo database)."
  type        = string
}

variable "python_version" {
  description = "Versión de Python de la Function."
  type        = string
  default     = "3.12"

  validation {
    condition     = contains(["3.11", "3.12"], var.python_version)
    error_message = "Las versiones de Python soportadas son 3.11 y 3.12."
  }
}

variable "instance_memory_mb" {
  description = "Memoria de cada instancia de la Function. Azure cobra por memoria × tiempo, así que menos memoria es más barato. Un contador no necesita más de 512 MB."
  type        = number
  default     = 512

  validation {
    condition     = contains([512, 2048, 4096], var.instance_memory_mb)
    error_message = "Flex Consumption solo permite 512, 2048 o 4096 MB."
  }
}

variable "max_instances" {
  description = "Máximo de copias de la Function que Azure puede levantar a la vez. Limita el gasto si hay mucho tráfico."
  type        = number
  default     = 40

  validation {
    condition     = var.max_instances >= 40 && var.max_instances <= 1000
    error_message = "Tiene que estar entre 40 y 1000 (límites del plan Flex Consumption)."
  }
}

variable "log_retention_days" {
  description = "Días que se guardan los logs. 30 es el mínimo que acepta Azure para este servicio."
  type        = number
  default     = 30

  validation {
    condition     = var.log_retention_days >= 30 && var.log_retention_days <= 90
    error_message = "Azure acepta entre 30 y 90 días sin costo extra de retención."
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
