resource "azurerm_resource_group" "lab" {
  name     = "rg-gavinbarbee-hybrid-identity"
  location = var.location
}

resource "azurerm_virtual_network" "lab" {
  name                = "vnet-gavinbarbee-hybrid"
  location            = azurerm_resource_group.lab.location
  resource_group_name = azurerm_resource_group.lab.name
  address_space       = ["10.60.0.0/16"]
}

resource "azurerm_subnet" "dc" {
  name                 = "snet-gavinbarbee-dc"
  resource_group_name  = azurerm_resource_group.lab.name
  virtual_network_name = azurerm_virtual_network.lab.name
  address_prefixes     = ["10.60.1.0/24"]
}

# Bastion requires this exact subnet name and at least a /26.
resource "azurerm_subnet" "bastion" {
  name                 = "AzureBastionSubnet"
  resource_group_name  = azurerm_resource_group.lab.name
  virtual_network_name = azurerm_virtual_network.lab.name
  address_prefixes     = ["10.60.2.0/26"]
}

# Only Bastion can reach the DC over RDP. The default rules deny all
# other inbound traffic from the internet.
resource "azurerm_network_security_group" "dc" {
  name                = "nsg-gavinbarbee-dc"
  location            = azurerm_resource_group.lab.location
  resource_group_name = azurerm_resource_group.lab.name

  security_rule {
    name                       = "Allow-RDP-From-Bastion"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "3389"
    source_address_prefix      = "10.60.2.0/26"
    destination_address_prefix = "*"
  }
}

resource "azurerm_subnet_network_security_group_association" "dc" {
  subnet_id                 = azurerm_subnet.dc.id
  network_security_group_id = azurerm_network_security_group.dc.id
}

resource "azurerm_public_ip" "bastion" {
  name                = "pip-gavinbarbee-bastion"
  location            = azurerm_resource_group.lab.location
  resource_group_name = azurerm_resource_group.lab.name
  allocation_method   = "Static"
  sku                 = "Standard"
}

resource "azurerm_bastion_host" "lab" {
  name                = "bas-gavinbarbee-hybrid"
  location            = azurerm_resource_group.lab.location
  resource_group_name = azurerm_resource_group.lab.name
  sku                 = "Basic"

  ip_configuration {
    name                 = "bastion-ipconfig"
    subnet_id            = azurerm_subnet.bastion.id
    public_ip_address_id = azurerm_public_ip.bastion.id
  }
}
