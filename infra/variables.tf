variable "resource_group_name" {
  type        = string
  description = "Pre-provisioned application resource group that Terraform manages resources inside of."
  default     = "housing-notes-rg"
}

variable "location" {
  type        = string
  description = "Azure region for the application resources."
  default     = "eastus"
}

variable "acr_name" {
  type        = string
  description = "Globally unique Azure Container Registry name (5-50 lowercase alphanumeric chars)."
  default     = "housingnotesacr"
}

variable "aks_name" {
  type        = string
  description = "Name of the AKS cluster."
  default     = "housing-notes-aks"
}

variable "aks_dns_prefix" {
  type        = string
  description = "DNS prefix for the AKS API server."
  default     = "housing-notes"
}

variable "aks_node_count" {
  type        = number
  description = "Number of nodes in the default node pool."
  default     = 2
}

variable "aks_node_vm_size" {
  type        = string
  description = "VM size for the default node pool."
  default     = "Standard_B2s"
}
