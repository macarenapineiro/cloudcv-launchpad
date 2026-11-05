locals {
  # azurerm no tiene "default_tags": este mapa se pasa a cada recurso.
  tags = {
    project = "cloudcv"
    team    = var.team
    env     = "dev"
    owner   = var.owner
  }
}

# El resource group lo crea el bootstrap. Acá solo se lee, porque el pipeline
# tiene permisos dentro de este grupo, pero no para crearlo.
data "azurerm_resource_group" "dev" {
  name = "rg-${var.prefix}-dev"
}