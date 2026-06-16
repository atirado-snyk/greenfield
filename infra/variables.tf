variable "location" {
  type        = string
  description = "Azure region for all resources."
  default     = "eastus"
}

variable "resource_group_name" {
  type        = string
  description = "Resource group that contains AKS and ACR."
  default     = "housing-notes-rg"
}

variable "aks_cluster_name" {
  type        = string
  description = "AKS cluster name."
  default     = "housing-notes-aks"
}

variable "aks_dns_prefix" {
  type        = string
  description = "DNS prefix for the AKS cluster."
  default     = "housing-notes"
}

variable "aks_node_count" {
  type        = number
  description = "Initial node count in the system pool."
  default     = 2
}

variable "aks_node_vm_size" {
  type        = string
  description = "VM size for the system node pool."
  default     = "Standard_B2s"
}

variable "acr_name" {
  type        = string
  description = "Azure Container Registry name (must be globally unique)."
  default     = "housingnotesacr"
}

variable "acr_sku" {
  type        = string
  description = "ACR SKU. Standard or above is required for image scanning."
  default     = "Standard"
}

variable "tags" {
  type        = map(string)
  description = "Tags applied to every resource."
  default = {
    project = "housing-notes"
    env     = "prod"
  }
}
