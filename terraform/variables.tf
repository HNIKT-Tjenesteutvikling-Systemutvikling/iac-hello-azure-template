variable "resource_group_name" {
  description = "Name of the Azure Resource Group"
  type        = string
  default     = "rg-hello-azure"
}

variable "location" {
  description = "Azure region where resources will be created"
  type        = string
  default     = "norwayeast"
}

variable "acr_name" {
  description = "Name of the Azure Container Registry (must be globally unique, lowercase alphanumeric)"
  type        = string
  default     = "acrhelloazure"
  
  validation {
    condition     = can(regex("^[a-z0-9]{5,50}$", var.acr_name))
    error_message = "ACR name must be 5-50 characters, lowercase alphanumeric only."
  }
}

variable "container_name" {
  description = "Name of the container instance (also used as DNS label - must be globally unique)"
  type        = string
  default     = "aci-hello-azure"
  
  validation {
    condition     = can(regex("^[a-z0-9]([a-z0-9-]{0,61}[a-z0-9])?$", var.container_name))
    error_message = "Container name must be 1-63 characters, lowercase alphanumeric and hyphens only, start and end with alphanumeric."
  }
}

variable "image_tag" {
  description = "Docker image tag to deploy"
  type        = string
  default     = "latest"
}
