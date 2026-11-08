# azapi crea la tabla del contador y configura el CORS de la Function,
# dos cosas que azurerm no puede hacer sin claves o sin fallar en el primer apply.
# En el pipeline toma la autenticación OIDC de las mismas variables ARM_* que azurerm.
provider "azapi" {
  subscription_id = var.subscription_id
}
