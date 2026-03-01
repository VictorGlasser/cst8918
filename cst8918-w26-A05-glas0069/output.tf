# Output the Resource Group name
output "resource_group_name" {
  value       = azurerm_resource_group.RG.name
  description = "The name of the Azure resource group created for this deployment"
}

# Output the Public IP of the VM
output "vm_public_ip" {
  value       = azurerm_public_ip.PIP.ip_address
  description = "The public IP address assigned to the virtual machine"
}