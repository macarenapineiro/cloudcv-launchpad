variable "budget_emails" {
  description = "Mails que reciben los avisos del presupuesto. Se cargan desde un archivo local (budget.auto.tfvars) que no se sube al repo."
  type        = list(string)

  validation {
    condition     = length(var.budget_emails) > 0 && alltrue([for m in var.budget_emails : can(regex("^[^@ ]+@[^@ ]+\\.[^@ ]+$", m))])
    error_message = "Tiene que haber al menos un mail y todos tienen que ser válidos."
  }
}

variable "budget_amount" {
  description = "Presupuesto mensual en USD."
  type        = number
  default     = 10
}

data "azurerm_subscription" "actual" {}

# Presupuesto de toda la suscripción, con avisos por mail al 50, 80 y 100 %.
resource "azurerm_consumption_budget_subscription" "proyecto" {
  name            = "budget-${var.prefix}"
  subscription_id = data.azurerm_subscription.actual.id
  amount          = var.budget_amount
  time_grain      = "Monthly"

  time_period {
    start_date = "2026-11-01T00:00:00Z"
  }

  dynamic "notification" {
    for_each = [50, 80, 100]
    content {
      enabled        = true
      threshold      = notification.value
      threshold_type = "Actual"
      operator       = "GreaterThanOrEqualTo"
      contact_emails = var.budget_emails
    }
  }
}