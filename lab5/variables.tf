variable "admin_password" {
  description = "Password for the administrator (localadmin). It should be complex"
  type        = string
  sensitive   = true
}

variable "location" {
  description = "Azure region for resource deployment"
  type        = string
  default     = "North Europe"
}