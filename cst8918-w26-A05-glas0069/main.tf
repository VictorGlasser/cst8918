# Configure the Terraform runtime requirements.
terraform {
  required_version = ">= 1.1.0"

  required_providers {
    # Azure Resource Manager provider and version
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.0.2"
    }
    cloudinit = {
      source  = "hashicorp/cloudinit"
      version = "2.3.3"
    }
  }
}

# Define providers and their config params
provider "azurerm" {
  # Leave the features block empty to accept all defaults
  features {}
}

provider "cloudinit" {
  # Configuration options
}

# Create a resource group
resource "azurerm_resource_group" "RG" {
  location = var.region
  name     = "${var.labelPrefix}-A05-RG"

  # Tag declaring that it is in the production environment
  tags = {
    environment = "Production"
  }
}

# Create Public IP address
resource "azurerm_public_ip" "PIP" {
  name                = "${var.labelPrefix}-A05-PIP"
  resource_group_name = azurerm_resource_group.RG.name
  location            = azurerm_resource_group.RG.location
  allocation_method   = "Static"

  # Tag declaring that it is in the production environment
  tags = {
    environment = "Production"
  }
}

# Create a virtual network within RG
resource "azurerm_virtual_network" "VNet" {
  name                = "${var.labelPrefix}-A05-VNet"
  resource_group_name = azurerm_resource_group.RG.name
  location            = azurerm_resource_group.RG.location
  address_space       = ["10.0.0.0/16"]

  # Tag declaring that it is in the production environment
  tags = {
    environment = "Production"
  }
}

# Create a subnet within the VNet
resource "azurerm_subnet" "SNet" {
  name                 = "${var.labelPrefix}-A05-SNet"
  resource_group_name  = azurerm_resource_group.RG.name
  virtual_network_name = azurerm_virtual_network.VNet.name
  address_prefixes     = ["10.0.1.0/24"]

  # Connects with NIC instead of delegation
 /* delegation {
    name = "delegation"

    service_delegation {
      name    = "Microsoft.ContainerInstance/containerGroups"
      actions = ["Microsoft.Network/virtualNetworks/subnets/join/action", "Microsoft.Network/virtualNetworks/subnets/prepareNetworkPolicies/action"]
    }
  }*/
}

# Creates Security Group
resource "azurerm_application_security_group" "SG" {
  name                = "${var.labelPrefix}-A05-SG"
  location            = azurerm_resource_group.RG.location
  resource_group_name = azurerm_resource_group.RG.name

  tags = {
    environment = "Production"
  }
}

# Create a network interface card (NIC)
resource "azurerm_network_interface" "NIC" {
  name                = "${var.labelPrefix}-A05-NIC"
  location            = azurerm_resource_group.RG.location
  resource_group_name = azurerm_resource_group.RG.name
  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.SNet.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.PIP.id
  }
  tags = {
    environment = "Production"
  }
}

# Create a cloud-init configuration for the VM
data "cloudinit_config" "config" {
  gzip          = false
  base64_encode = false 
  part {#!!!!
    content_type = "text/cloud-config"
    content      = <<-EOT
      #cloud-config
      package_upgrade: true
      packages:
        - nginx
      runcmd:
        - systemctl start nginx
        - systemctl enable nginx
    EOT
  }
}

# Create Linux Virtual Machine
resource "azurerm_linux_virtual_machine" "VM" {
  name                = "${var.labelPrefix}-A05-VM"
  resource_group_name = azurerm_resource_group.RG.name
  location            = azurerm_resource_group.RG.location
  size                = "Standard_B1s"
  admin_username      = "glas0069"
  network_interface_ids = [
    azurerm_network_interface.NIC.id,
  ]

  admin_ssh_key {
    username   = "glas0069"
    public_key = file("~/.ssh/id_rsa.pub")
  }

  custom_data = data.cloudinit_config.config.rendered

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts"
    version   = "latest"
  }
}