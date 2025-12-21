output "lb_public_ip" {
  value = azurerm_public_ip.lb_pip.ip_address
}

output "appgw_public_ip" {
  value = azurerm_public_ip.appgw_pip.ip_address
}