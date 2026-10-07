variable "subscription_id" {
  description = "Azure subscription to deploy into."
  type        = string
}

variable "location" {
  description = "Azure region. eastus2 by default; centralus is the fallback if quota is short."
  type        = string
  default     = "eastus2"
}

variable "vm_size" {
  description = "Domain controller VM size."
  type        = string
  default     = "Standard_D2alds_v7"
}

variable "admin_username" {
  description = "Local admin on the VM. Becomes the domain's built-in Administrator after promotion."
  type        = string
  default     = "dcadmin"
}

variable "dc_private_ip" {
  description = "Static private IP for the domain controller."
  type        = string
  default     = "10.60.1.4"
}

variable "auto_shutdown_time" {
  description = "Daily auto-shutdown time (24h, HHMM)."
  type        = string
  default     = "1900"
}

variable "auto_shutdown_timezone" {
  description = "Time zone for the auto-shutdown schedule."
  type        = string
  default     = "Pacific Standard Time"
}
