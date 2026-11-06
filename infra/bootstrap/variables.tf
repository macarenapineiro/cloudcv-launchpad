variable "subscription_id" {
  description = "ID de la suscripción Azure for Students donde se crea todo."
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
  description = "Prefijo de nombres (sin guiones, porque las Storage Accounts no los admiten)."
  type        = string
  default     = "cloudcv"
}

variable "team" {
  description = "Nombre del equipo, para la etiqueta team."
  type        = string
  default     = "cloudcv-ucu"
}

variable "owner" {
  description = "Responsable del recurso, para la etiqueta owner."
  type        = string
  default     = "juliana.hernandez"
}

variable "github_repo" {
  description = "Repositorio de GitHub (dueño/nombre) autorizado a usar la identidad."
  type        = string
  default     = "macarenapineiro/cloudcv-launchpad"
}

variable "github_environment" {
  description = "Nombre del environment de GitHub usado para el apply con aprobación manual."
  type        = string
  default     = "dev"
}

variable "state_users" {
  description = "Integrantes del equipo con acceso de lectura y escritura al state (nombre => object ID en Microsoft Entra ID). Son identificadores, no secretos."
  type        = map(string)
  default = {
    juliana  = "76b5b5a8-8b0e-428f-af6c-36a1496d5f82"
    macarena = "afa30903-4771-475e-857c-725882688b05"
  }
}