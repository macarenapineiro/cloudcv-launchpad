variable "resource_group_name" {
  description = "Nombre del resource group donde se crea la cuenta de Storage de datos."
  type        = string
}

variable "location" {
  description = "Región de Azure donde se crea la cuenta de Storage de datos."
  type        = string

  validation {
    condition     = contains(["chilecentral", "mexicocentral", "canadacentral", "northcentralus", "brazilsouth"], var.location)
    error_message = "La región tiene que ser una de las permitidas por la suscripción Azure for Students."
  }
}

variable "prefix" {
  description = "Prefijo para el nombre de la cuenta de Storage (solo minúsculas y números)."
  type        = string
  default     = "cloudcv"

  validation {
    condition     = can(regex("^[a-z0-9]{3,12}$", var.prefix))
    error_message = "El prefijo tiene que tener entre 3 y 12 letras minúsculas o números, sin guiones."
  }
}

variable "table_name" {
  description = "Nombre de la tabla donde se guarda el contador de visitas."
  type        = string
  default     = "visitas"

  validation {
    condition     = can(regex("^[A-Za-z][A-Za-z0-9]{2,62}$", var.table_name))
    error_message = "El nombre de la tabla tiene que empezar con una letra y tener solo letras y números (3 a 63 caracteres)."
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
