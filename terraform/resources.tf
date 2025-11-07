# Resource Group
resource "azurerm_resource_group" "main" {
  name     = var.resource_group_name
  location = var.location

  tags = {
    Environment = "Demo"
    Project     = "IaC-Hello-Azure"
  }
}

# Azure Container Registry
resource "azurerm_container_registry" "acr" {
  name                = var.acr_name
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  sku                 = "Basic"
  # Admin enabled for simplicity in demo scenarios
  # For production, consider using managed identity or service principal authentication
  admin_enabled       = true

  tags = {
    Environment = "Demo"
    Project     = "IaC-Hello-Azure"
  }
}

# Azure Container Instance
resource "azurerm_container_group" "aci" {
  name                = var.container_name
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  os_type             = "Linux"
  dns_name_label      = var.container_name
  ip_address_type     = "Public"

  image_registry_credential {
    server   = azurerm_container_registry.acr.login_server
    username = azurerm_container_registry.acr.admin_username
    password = azurerm_container_registry.acr.admin_password
  }

  container {
    name   = "hello-azure"
    image  = "${azurerm_container_registry.acr.login_server}/hello-azure:${var.image_tag}"
    cpu    = "0.5"
    memory = "1.0"

    ports {
      port     = 80
      protocol = "TCP"
    }
  }

  tags = {
    Environment = "Demo"
    Project     = "IaC-Hello-Azure"
  }
}
