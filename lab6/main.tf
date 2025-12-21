resource "azurerm_resource_group" "rg" {
  name     = var.resource_group_name
  location = var.location
}

resource "azurerm_virtual_network" "vnet" {
  name                = "az104-06-vnet1"
  address_space       = ["10.60.0.0/16"]
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
}

resource "azurerm_subnet" "subnets" {
  count                = 3
  name                 = "subnet${count.index}"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.60.${count.index}.0/24"]
}

resource "azurerm_network_security_group" "nsg" {
  name                = "az104-06-nsg"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  security_rule {
    name                       = "AllowHTTP"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "80"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}

resource "azurerm_network_interface" "nics" {
  count               = 3
  name                = "az104-06-nic${count.index}"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.subnets[count.index].id
    private_ip_address_allocation = "Dynamic"
  }
}

resource "azurerm_network_interface_security_group_association" "nsg_assoc" {
  count                     = 3
  network_interface_id      = azurerm_network_interface.nics[count.index].id
  network_security_group_id = azurerm_network_security_group.nsg.id
}

resource "azurerm_windows_virtual_machine" "vms" {
  count               = 3
  name                = "az104-06-vm${count.index}"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  size                = var.vm_size
  admin_username      = var.admin_username
  admin_password      = var.admin_password
  network_interface_ids = [azurerm_network_interface.nics[count.index].id]

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "MicrosoftWindowsServer"
    offer     = "WindowsServer"
    sku      = "2019-Datacenter"
    version   = "latest"
  }
}

resource "azurerm_public_ip" "lb_pip" {
  name                = "az104-lbpip"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  allocation_method   = "Static"
  sku                 = "Standard"
}

resource "azurerm_lb" "lb" {
  name                = "az104-lb"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  sku                 = "Standard"

  frontend_ip_configuration {
    name                 = "az104-fe"
    public_ip_address_id = azurerm_public_ip.lb_pip.id
  }
}

resource "azurerm_lb_backend_address_pool" "lb_be" {
  loadbalancer_id = azurerm_lb.lb.id
  name            = "az104-be"
}

resource "azurerm_lb_backend_address_pool_address" "vm_assoc" {
  count                   = 2
  name                    = "vm${count.index}-address"
  backend_address_pool_id = azurerm_lb_backend_address_pool.lb_be.id
  virtual_network_id      = azurerm_virtual_network.vnet.id
  ip_address              = azurerm_network_interface.nics[count.index].private_ip_address
}

resource "azurerm_lb_probe" "hp" {
  loadbalancer_id = azurerm_lb.lb.id
  name            = "az104-hp"
  port            = 80
  protocol        = "Tcp"
  interval_in_seconds = 5
}

resource "azurerm_lb_rule" "lb_rule" {
  loadbalancer_id                = azurerm_lb.lb.id
  name                           = "az104-lbrule"
  protocol                       = "Tcp"
  frontend_port                  = 80
  backend_port                   = 80
  frontend_ip_configuration_name = "az104-fe"
  backend_address_pool_ids        = [azurerm_lb_backend_address_pool.lb_be.id]
  probe_id                       = azurerm_lb_probe.hp.id
}

resource "azurerm_subnet" "appgw_subnet" {
  name                 = "subnet-appgw"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.60.3.224/27"]
}

resource "azurerm_public_ip" "appgw_pip" {
  name                = "az104-gwpip"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  allocation_method   = "Static"
  sku                 = "Standard"
}

resource "azurerm_application_gateway" "appgw" {
  name                = "az104-appgw"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location

  sku {
    name     = "Standard_v2"
    tier     = "Standard_v2"
    capacity = 2
  }

  ssl_policy {
    policy_type = "Predefined"
    policy_name = "AppGwSslPolicy20170401S"
  }

  gateway_ip_configuration {
    name      = "my-gateway-ip-configuration"
    subnet_id = azurerm_subnet.appgw_subnet.id
  }

  frontend_port {
    name = "fe-port"
    port = 80
  }

  frontend_ip_configuration {
    name                 = "fe-ip"
    public_ip_address_id = azurerm_public_ip.appgw_pip.id
  }

  backend_address_pool {
    name = "az104-appgwbe"
    ip_addresses = [
      azurerm_network_interface.nics[0].private_ip_address,
      azurerm_network_interface.nics[1].private_ip_address
    ]
  }

  backend_address_pool {
    name = "az104-imagebe"
    ip_addresses = [azurerm_network_interface.nics[1].private_ip_address]
  }

  backend_address_pool {
    name = "az104-videobe"
    ip_addresses = [azurerm_network_interface.nics[2].private_ip_address]
  }

  backend_http_settings {
    name                  = "http-settings"
    cookie_based_affinity = "Disabled"
    port                  = 80
    protocol              = "Http"
    request_timeout       = 60
  }

  http_listener {
    name                           = "listener"
    frontend_ip_configuration_name = "fe-ip"
    frontend_port_name             = "fe-port"
    protocol                       = "Http"
  }

  request_routing_rule {
    name               = "az104-gwrule"
    rule_type          = "PathBasedRouting"
    http_listener_name = "listener"
    url_path_map_name  = "url-path-map"
    priority           = 10
  }

  url_path_map {
    name                               = "url-path-map"
    default_backend_address_pool_name  = "az104-appgwbe"
    default_backend_http_settings_name = "http-settings"

    path_rule {
      name                       = "image-rule"
      paths                      = ["/image/*"]
      backend_address_pool_name  = "az104-imagebe"
      backend_http_settings_name = "http-settings"
    }

    path_rule {
      name                       = "video-rule"
      paths                      = ["/video/*"]
      backend_address_pool_name  = "az104-videobe"
      backend_http_settings_name = "http-settings"
    }
  }
}