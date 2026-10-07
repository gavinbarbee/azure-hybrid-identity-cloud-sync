resource "random_password" "admin" {
  length      = 24
  special     = true
  min_upper   = 2
  min_lower   = 2
  min_numeric = 2
  min_special = 2
}

# The DC points DNS at itself. Before promotion nothing needs DNS;
# after promotion its DNS server forwards internet lookups to Azure DNS.
resource "azurerm_network_interface" "dc" {
  name                = "nic-gavinbarbee-dc01"
  location            = azurerm_resource_group.lab.location
  resource_group_name = azurerm_resource_group.lab.name
  dns_servers         = [var.dc_private_ip]

  ip_configuration {
    name                          = "ipconfig1"
    subnet_id                     = azurerm_subnet.dc.id
    private_ip_address_allocation = "Static"
    private_ip_address            = var.dc_private_ip
  }
}

resource "azurerm_windows_virtual_machine" "dc" {
  name                  = "vm-gavinbarbee-dc01"
  computer_name         = "DC01"
  location              = azurerm_resource_group.lab.location
  resource_group_name   = azurerm_resource_group.lab.name
  size                  = var.vm_size
  admin_username        = var.admin_username
  admin_password        = random_password.admin.result
  network_interface_ids = [azurerm_network_interface.dc.id]

  os_disk {
    name                 = "osdisk-gavinbarbee-dc01"
    caching              = "ReadWrite"
    storage_account_type = "StandardSSD_LRS"
  }

  source_image_reference {
    publisher = "MicrosoftWindowsServer"
    offer     = "WindowsServer"
    sku       = "2022-datacenter-g2"
    version   = "latest"
  }
}

# The AD database and SYSVOL live on their own disk with host caching
# off, so AD writes are never held in a host cache.
resource "azurerm_managed_disk" "ntds" {
  name                 = "disk-gavinbarbee-dc01-ntds"
  location             = azurerm_resource_group.lab.location
  resource_group_name  = azurerm_resource_group.lab.name
  storage_account_type = "StandardSSD_LRS"
  create_option        = "Empty"
  disk_size_gb         = 16
}

resource "azurerm_virtual_machine_data_disk_attachment" "ntds" {
  managed_disk_id    = azurerm_managed_disk.ntds.id
  virtual_machine_id = azurerm_windows_virtual_machine.dc.id
  lun                = 0
  caching            = "None"
}

resource "azurerm_dev_test_global_vm_shutdown_schedule" "dc" {
  virtual_machine_id    = azurerm_windows_virtual_machine.dc.id
  location              = azurerm_resource_group.lab.location
  enabled               = true
  daily_recurrence_time = var.auto_shutdown_time
  timezone              = var.auto_shutdown_timezone

  notification_settings {
    enabled = false
  }
}
