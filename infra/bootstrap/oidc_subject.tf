# GitHub presenta en el token OIDC el ID numérico del dueño y del repositorio
# (repo:dueño@ID/repo@ID:...). La credencial federada tiene que coincidir exacto.
# Atar la confianza a los IDs, y no solo al nombre, evita que otro repo con el mismo
# nombre pueda usar la identidad.
variable "github_owner_id" {
  description = "ID numérico del dueño del repositorio en GitHub (aparece en el subject del token OIDC)."
  type        = string
  default     = "167207590"
}

variable "github_repo_id" {
  description = "ID numérico del repositorio en GitHub (aparece en el subject del token OIDC)."
  type        = string
  default     = "1445917015"
}

locals {
  github_subject_prefix = "repo:${split("/", var.github_repo)[0]}@${var.github_owner_id}/${split("/", var.github_repo)[1]}@${var.github_repo_id}"
}