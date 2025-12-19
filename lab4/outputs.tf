
output "public_dns_name_servers" {
  description = "Name servers for the public DNS zone. Use one of these for nslookup."
  value       = azurerm_dns_zone.public.name_servers
}