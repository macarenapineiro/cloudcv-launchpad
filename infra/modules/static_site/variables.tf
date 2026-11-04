variable "resource_group_name" {
  description = "Nombre del resource group donde se crea la cuenta de Storage."
  type        = string
}

variable "location" {
  description = "Región de Azure donde se crea la cuenta de Storage."
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

variable "site_path" {
  description = "Carpeta local con los archivos del sitio (index.html, style.css, script.js)."
  type        = string
}

variable "tags" {
  description = "Etiquetas obligatorias: project, team, env y owner."
  type        = map(string)

  validation {
    condition     = alltrue([for t in ["project", "team", "env", "owner"] : contains(keys(var.tags), t)])
    error_message = "Faltan etiquetas: tienen que estar project, team, env y owner."
  }
}
