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
  description = "Name of the Azure Container Registry"
  type        = string
  default     = "acrhelloazure"
}

variable "container_name" {
  description = "Name of the container instance"
  type        = string
  default     = "aci-hello-azure"
}

variable "image_tag" {
  description = "Docker image tag to deploy"
  type        = string
  default     = "latest"
}
