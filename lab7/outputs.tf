output "storage_account_primary_blob_endpoint" {
  value = azurerm_storage_account.storage.primary_blob_endpoint
}

output "sas_url_instruction" {
  value = "Use the Azure Portal or CLI to generate a SAS token for a specific file"
}