variable "internal_domain" {
  type = string
  default = "internal"
  description = "Top level domain"
}

variable "authentik_bootstrap_email" {
  type = string
  sensitive = true
}

variable "authentik_bootstrap_password" {
  type = string
  sensitive = true
}

variable "guacamole_admin_username" {
  default = "guacadmin"
  type = string
}

variable "guacamole_admin_password" {
  sensitive = true
  type = string
}