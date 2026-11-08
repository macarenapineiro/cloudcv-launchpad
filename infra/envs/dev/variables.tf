variable "subscription_id" {
  description = "ID de la suscripción Azure for Students."
  type        = string
  default     = "df8b465b-e672-406d-8d2f-bd660f8a6d2e"
}

variable "location" {
  description = "Región de Azure. Solo las permitidas por la suscripción."
  type        = string
  default     = "canadacentral"

  validation {
    condition     = contains(["chilecentral", "mexicocentral", "canadacentral", "northcentralus", "brazilsouth"], var.location)
    error_message = "La suscripción solo permite chilecentral, mexicocentral, canadacentral, northcentralus o brazilsouth."
  }
}

variable "prefix" {
  description = "Prefijo de nombres (sin guiones)."
  type        = string
  default     = "cloudcv"
}

variable "team" {
  description = "Nombre del equipo, para la etiqueta team."
  type        = string
  default     = "cloudcv-ucu"
}

variable "owner" {
  description = "Responsable de los recursos, para la etiqueta owner."
  type        = string
  default     = "juliana.hernandez"
}

variable "alert_emails" {
  description = "Mails que reciben el aviso de la alerta de errores. No se escriben en el código: en el pipeline vienen del secret ALERT_EMAILS del repo y, en una compu, de un terraform.tfvars (ignorado por git)."
  type        = list(string)
}
