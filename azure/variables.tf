variable "location" {
  description = "Azure region (must be allowed by the Azure for Students policy)"
  type        = string
  default     = "polandcentral"
}

variable "project_name" {
  type    = string
  default = "meetings"
}

variable "resource_group_name" {
  type    = string
  default = "rg-meetings-lab9"
}

variable "db_location" {
  description = "Region for PostgreSQL. null = same as location. Set it if the region is restricted for Flexible Server on Azure for Students."
  type        = string
  default     = null
}

variable "my_ip" {
  description = "Your public IP, allowed to reach the database from your laptop (for migrations)"
  type        = string
  default     = ""
}

variable "db_sku_name" {
  description = "PostgreSQL Flexible Server SKU, for example B_Standard_B1ms or B_Standard_B2s"
  type        = string
  default     = "B_Standard_B1ms"
}
