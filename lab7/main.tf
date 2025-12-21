resource "azurerm_resource_group" "rg" {
  name     = var.resource_group_name
  location = var.location
}

resource "azurerm_storage_account" "storage" {
  name                     = var.storage_account_name
  resource_group_name      = azurerm_resource_group.rg.name
  location                 = azurerm_resource_group.rg.location
  account_tier             = "Standard"
  account_replication_type = "GRS"
  access_tier              = "Hot"

  public_network_access_enabled = true 
  
  blob_properties {
    delete_retention_policy {
      days = 7
    }

    versioning_enabled = false
  }

  network_rules {
    default_action = "Allow" 
    bypass         = ["AzureServices"]
  }
}

resource "azurerm_storage_container" "blob_container" {
  name                  = var.blob_container_name
  storage_account_name  = azurerm_storage_account.storage.name
  container_access_type = "private"
}

resource "azurerm_storage_management_policy" "lifecycle" {
  storage_account_id = azurerm_storage_account.storage.id

  rule {
    name    = "Movetocool"
    enabled = true
    filters {
      blob_types   = ["blockBlob"]
    }
    actions {
      base_blob {
        tier_to_cool_after_days_since_modification_greater_than = 30
      }
    }
  }
}

resource "azurerm_storage_share" "file_share" {
  name                 = var.file_share_name
  storage_account_name = azurerm_storage_account.storage.name
  quota                = 5120
}

resource "azurerm_virtual_network" "vnet" {
  name                = var.vnet_name
  address_space       = ["10.0.0.0/16"]
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
}

resource "azurerm_subnet" "default_subnet" {
  name                 = "default"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.0.0.0/24"]

  service_endpoints = ["Microsoft.Storage"]
}

resource "azurerm_storage_account_network_rules" "network_rules" {
  storage_account_id = azurerm_storage_account.storage.id

  default_action             = "Deny"
  virtual_network_subnet_ids = [azurerm_subnet.default_subnet.id]
  bypass                     = ["AzureServices"]
  
  depends_on = [azurerm_virtual_network.vnet]
}