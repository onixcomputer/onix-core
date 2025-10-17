# Terraform variables for Keycloak testing
# Generated on: 2025-10-16

# Keycloak authentication variables
keycloak_admin_password = "test-password-placeholder"
keycloak_url = "https://auth.robitzs.ch:9081"
keycloak_realm = "master"
keycloak_admin_username = "admin"
keycloak_client_id = "admin-cli"

# Advanced configuration
keycloak_client_timeout = 60
keycloak_initial_login = false
keycloak_tls_insecure_skip_verify = false

# Instance configuration
instance_name = "adeci"
domain = "auth.robitzs.ch"
nginx_port = 9081