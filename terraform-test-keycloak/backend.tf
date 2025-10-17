# Terraform backend configuration for Keycloak instance: adeci
terraform {
  backend "local" {
    path = "terraform.tfstate"
  }
}