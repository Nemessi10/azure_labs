variable "resource_group_name" {
  description = "Resource group name"
  default     = "az104-rg7"
}

variable "location" {
  description = "Region"
  default     = "East US"
}

variable "storage_account_name" {
  description = "Unique storage account name (3-24 characters, letters and numbers only)"
  default     = "stg104lab7superunique"
}

variable "vnet_name" {
  default = "vnet1"
}

variable "blob_container_name" {
  default = "data"
}

variable "file_share_name" {
  default = "share1"
}