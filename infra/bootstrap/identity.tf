locals {
  # Roles que el pipeline puede asignar (IDs oficiales de Azure).
  allowed_role_ids = join(", ", [
    "0a9a7e1f-b9d0-4cc4-a60d-0319b160aaa3", # Storage Table Data Contributor
    "ba92f5b4-2d11-453d-a403-e96b0029c9fe", # Storage Blob Data Contributor
  ])

  github_issuer   = "https://token.actions.githubusercontent.com"
  github_audience = ["api://AzureADTokenExchange"]
}

# Resource group donde el pipeline despliega el proyecto (envs/dev).
resource "azurerm_resource_group" "dev" {
  name     = "rg-${var.prefix}-dev"
  location = var.location
  tags     = merge(local.tags, { env = "dev" })
}

# "Usuario robot" del pipeline.
resource "azurerm_user_assigned_identity" "github" {
  name                = "id-${var.prefix}-github"
  resource_group_name = azurerm_resource_group.tfstate.name
  location            = azurerm_resource_group.tfstate.location
  tags                = local.tags
}

# Credenciales federadas, de a una (depends_on) porque Azure rechaza
# escrituras simultáneas sobre la misma identidad.
resource "azurerm_federated_identity_credential" "main" {
  name      = "github-main"
  parent_id = azurerm_user_assigned_identity.github.id
  audience  = local.github_audience
  issuer    = local.github_issuer
  subject   = "${local.github_subject_prefix}:ref:refs/heads/main"
}

resource "azurerm_federated_identity_credential" "pull_request" {
  name      = "github-pull-request"
  parent_id = azurerm_user_assigned_identity.github.id
  audience  = local.github_audience
  issuer    = local.github_issuer
  subject   = "${local.github_subject_prefix}:pull_request"

  depends_on = [azurerm_federated_identity_credential.main]
}

resource "azurerm_federated_identity_credential" "environment" {
  name      = "github-environment-${var.github_environment}"
  parent_id = azurerm_user_assigned_identity.github.id
  audience  = local.github_audience
  issuer    = local.github_issuer
  subject   = "${local.github_subject_prefix}:environment:${var.github_environment}"

  depends_on = [azurerm_federated_identity_credential.pull_request]
}

# 1) State remoto: solo el contenedor tfstate.
resource "azurerm_role_assignment" "state" {
  scope                = azurerm_storage_container.tfstate.id
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = azurerm_user_assigned_identity.github.principal_id
  principal_type       = "ServicePrincipal"
}

# 2) Crear recursos: solo el resource group de dev.
resource "azurerm_role_assignment" "contributor_dev" {
  scope                = azurerm_resource_group.dev.id
  role_definition_name = "Contributor"
  principal_id         = azurerm_user_assigned_identity.github.principal_id
  principal_type       = "ServicePrincipal"
}

# 3) Crear asignaciones de rol, pero solo de los roles permitidos.
resource "azurerm_role_assignment" "rbac_admin_dev" {
  scope                = azurerm_resource_group.dev.id
  role_definition_name = "Role Based Access Control Administrator"
  principal_id         = azurerm_user_assigned_identity.github.principal_id
  principal_type       = "ServicePrincipal"
  condition_version    = "2.0"
  condition            = <<-EOT
    (
     (
      !(ActionMatches{'Microsoft.Authorization/roleAssignments/write'})
     )
     OR
     (
      @Request[Microsoft.Authorization/roleAssignments:RoleDefinitionId] ForAnyOfAnyValues:GuidEquals {${local.allowed_role_ids}}
     )
    )
    AND
    (
     (
      !(ActionMatches{'Microsoft.Authorization/roleAssignments/delete'})
     )
     OR
     (
      @Resource[Microsoft.Authorization/roleAssignments:RoleDefinitionId] ForAnyOfAnyValues:GuidEquals {${local.allowed_role_ids}}
     )
    )
  EOT
}

# Permiso de cada integrante del equipo sobre el contenedor del state,
# para poder correr tofu plan desde su computadora.
resource "azurerm_role_assignment" "state_users" {
  for_each             = var.state_users
  scope                = azurerm_storage_container.tfstate.id
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = each.value
  principal_type       = "User"
}