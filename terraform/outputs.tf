output "resource_group_id" {
  value = azurerm_resource_group.dmartinezg-1.id
}

output "vm_id" {
  value = azurerm_linux_virtual_machine.vm.id
}

output "public_ip" {
  value = azurerm_public_ip.dmartinezg-1_public_ip.ip_address
}

