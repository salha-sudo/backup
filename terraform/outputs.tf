output "storage_account_name" {
  value = azurerm_storage_account.backup.name
}

output "container_name" {
  value = azurerm_storage_container.offsite.name
}

output "storage_account_key" {
  value     = azurerm_storage_account.backup.primary_access_key
  sensitive = true
}
