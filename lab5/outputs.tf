
output "core_vm_private_ip" {
  description = "Private IP address of the CoreServicesVM virtual machine (for Task 5)"
  value       = azurerm_windows_virtual_machine.core_vm.private_ip_address
}