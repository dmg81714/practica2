resource "azurerm_resource_group" "dmartinezg-1" {
  name     = var.resource_group_name
  location = var.location_name
}

resource "azurerm_virtual_network" "vnet" {
  name                = var.network_name
  address_space       = ["10.0.0.0/16"]
  location            = azurerm_resource_group.dmartinezg-1.location
  resource_group_name = azurerm_resource_group.dmartinezg-1.name
}

resource "azurerm_subnet" "subnet" {
  name                 = var.subnet_name
  resource_group_name  = azurerm_resource_group.dmartinezg-1.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.0.2.0/24"]
}

resource "azurerm_network_interface" "dmartinezg-1_nic" {
  name                = "vnic"
  location            = azurerm_resource_group.dmartinezg-1.location
  resource_group_name = azurerm_resource_group.dmartinezg-1.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.subnet.id
    private_ip_address_allocation = "Dynamic"
	public_ip_address_id		  = azurerm_public_ip.dmartinezg-1_public_ip.id
  }
}

resource "azurerm_public_ip" "dmartinezg-1_public_ip" {
  name                = "public_ip"
  location            = azurerm_resource_group.dmartinezg-1.location
  resource_group_name = azurerm_resource_group.dmartinezg-1.name
  allocation_method   = "Static"
  sku                 = "Standard"
}

resource "azurerm_linux_virtual_machine" "vm" {
  name                = "vm1"
  resource_group_name = azurerm_resource_group.dmartinezg-1.name
  location            = azurerm_resource_group.dmartinezg-1.location
  size                = "Standard_F2"
  admin_username      = "azureuser"
  network_interface_ids = [
    azurerm_network_interface.dmartinezg-1_nic.id,
  ]

  admin_ssh_key {
    username   = "azureuser"
    public_key = file("/etc/ssh/dmartinezg_ssh.pub")
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  plan {
    name      = "centos-8-stream-free"
    product   = "centos-8-stream-free"
    publisher = "cognosys"
  }


  source_image_reference {
    publisher = "cognosys"
    offer     = "centos-8-stream-free"
    sku       = "centos-8-stream-free"
    version   = "22.03.28"
  }
}

# Create Network Security Group and rule
resource "azurerm_network_security_group" "dmartinezg-1_nsg" {
  name                = "dmartinezg-1_nsg"
  location            = azurerm_resource_group.dmartinezg-1.location
  resource_group_name = azurerm_resource_group.dmartinezg-1.name

  security_rule {
    name                       = "SSH"
    priority                   = 1001
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = "*"
    destination_address_prefix = "*"	
	}
	security_rule {
    name                       = "http"
    priority                   = 1002
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "8080"
    source_address_prefix      = "*"
    destination_address_prefix = "*"	  
    }
}	

resource "azurerm_network_interface_security_group_association" "association" {
  network_interface_id      = azurerm_network_interface.dmartinezg-1_nic.id
  network_security_group_id = azurerm_network_security_group.dmartinezg-1_nsg.id
}

resource "azurerm_container_registry" "dmartinezg-1_acr" {
  name                = "dmartinezgacr1"
  resource_group_name = azurerm_resource_group.dmartinezg-1.name
  location            = azurerm_resource_group.dmartinezg-1.location
  sku                 = "Premium"
  admin_enabled       = false
}

resource "azurerm_kubernetes_cluster" "dmartinezg-1_akc" {
  name                = "dmartinezgakc1"
  location            = azurerm_resource_group.dmartinezg-1.location
  resource_group_name = azurerm_resource_group.dmartinezg-1.name
  dns_prefix          = "dmartinezgaks1"

  default_node_pool {
    name       = "default"
    node_count = 1
    vm_size    = "Standard_D2_v2"
  }

  identity {
    type = "SystemAssigned"
  }

  tags = {
    Environment = "Production"
  }
}

resource "azurerm_role_assignment" "dmartinezg-1_arz" {
  principal_id                     = azurerm_kubernetes_cluster.dmartinezg-1_akc.kubelet_identity[0].object_id
  role_definition_name             = "AcrPull"
  scope                            = azurerm_container_registry.dmartinezg-1_acr.id
  skip_service_principal_aad_check = true
}

