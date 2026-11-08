variable "subscription_id" {
  description = "ID de l'abonnement Azure for Students (az account show --query id -o tsv)"
  type        = string
}

variable "location" {
  description = "Région Azure. Azure for Students limite parfois les régions : essaie francecentral, swedencentral, northeurope..."
  type        = string
  default     = "francecentral"
}
