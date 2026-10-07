output "resource_group" {
  value = azurerm_resource_group.lab.name
}

output "vm_name" {
  value = azurerm_windows_virtual_machine.dc.name
}

output "dc_private_ip" {
  value = var.dc_private_ip
}

output "admin_username" {
  value = var.admin_username
}

output "admin_password" {
  description = "Read in the terminal only."
  value       = random_password.admin.result
  sensitive   = true
}
