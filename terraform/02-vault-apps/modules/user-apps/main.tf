terraform {
  required_providers {   
    authentik = {
      source  = "goauthentik/authentik"
      version = "2025.12.1"
    }
  }
}

# Run Authentik Init job
resource "nomad_job" "authentik-bootstrap" {
  jobspec = templatefile("${path.root}/templates/authentik-bootstrap.hcl.tpl", {})
  detach = false
}
# Wait for the batch job to exit before starting the rest of Authentik
# Even when depends_on authentik-bootstrap, Terraform does not wait for the job to actually be completed, just registered
resource "null_resource" "await-bootstrap" {
  depends_on = [nomad_job.authentik-bootstrap]

  provisioner "remote-exec" {
    inline = [
      "echo 'Waiting for Authentik Bootstrap (batch job) to finish...'",
      <<-EOT
      while true; do
        # Check for dead or failed. After piping through grep we get:
        # Status        = dead (stopped) # Use awk to pull 3rd column, 'dead'.
        STATUS=$(nomad job status -short authentik-bootstrap 2>/dev/null | grep 'Status' | awk '{print $3}')
        
        if [ "$STATUS" = "dead" ]; then
          echo "Bootstrap migration completed successfully."
          exit 0
        elif [ "$STATUS" = "failed" ]; then
          echo "Bootstrap migration FAILED. Check 'nomad alloc logs'."
          exit 1
        fi

        echo "Current status: $${STATUS:-starting}... sleeping 10s"
        sleep 10
      done
      EOT
    ]
  }
  connection {
    host = var.leader_address
    type = "ssh"
    user = "ubuntu"
  }
}

# After bootstrap launch Authentik on all nodes
resource "nomad_job" "authentik" {
  jobspec = templatefile("${path.root}/templates/authentik.hcl.tpl", {})

  depends_on = [ null_resource.await-bootstrap ]
  # Destroy so that on reapply Terraform does not error
  purge_on_destroy = true
  detach = false
}

# Becuase of some questionable choices we need to install our cert manully though terraform to Authentik
# This is because when attempting to set it manually via the brand resource web_certificate expects a UUID
# This UUID is internal to Authentik and cannot be extracted from Vault or the actual pem file :(
resource "authentik_certificate_key_pair" "vault_keys" {
  depends_on      = [ null_resource.delete_default_brand ]
  name             = "authentik"
  # Pull the key pair directly from Vault
  certificate_data = var.authentik_cert
  key_data         = var.authentik_key
}


# This piece of code is ugly but it works
# My biggest fight has been Authentik not knowing to maybe use the certs I defined in /certs/ for the webserver
# So we have this abomination check that it is online first
# Delete the authentik-defualt domain, but only if it exits. This prevents a reapply from causing headaches if default is already deleted
resource "null_resource" "delete_default_brand" {
  depends_on = [nomad_job.authentik]

  provisioner "remote-exec" {
    connection {
      type = "ssh"
      host = var.leader_address
      user = "ubuntu"
    }

    inline = [
      "#!/bin/bash",
      # 1. Wait for API to be ready
      "echo 'Waiting for Authentik API...'",
      "while ! curl -s -o /dev/null -w '%%{http_code}' http://${var.leader_address}:9000/-/health/live/ | grep -q '200'; do sleep 2; done",
      
      # 2. Get the UUID for the brand with domain 'authentik-default'
      # Use JQ to grab the UUID of the default domain
      "JSON_DATA=$(curl -s -H 'Authorization: Bearer ${var.authentik_token}' http://${var.leader_address}:9000/api/v3/core/brands/)",
      "BRAND_ID=$(echo $JSON_DATA | jq -r '.results[] | select(.default == true) | .brand_uuid')",

      # 3. IF BRAND_ID is not empty, DELETE it. If empty, skip.
      "if [ ! -z \"$BRAND_ID\" ]; then",
      "  echo \"Found default brand $BRAND_ID, deleting...\"",
      "  curl -i -X DELETE \"http://${var.leader_address}:9000/api/v3/core/brands/$BRAND_ID/\" -H 'Authorization: Bearer ${var.authentik_token}'",
      "else",
      "  echo 'Default brand not found, skipping deletion.'",
      "fi",
      # Verify deletion
      "if [ ! -z \"$BRAND_ID\" ]; then",
      "  curl -s -X DELETE -H 'Authorization: Bearer ${var.authentik_token}' http://${var.leader_address}:9000/api/v3/core/brands/$BRAND_ID/",
      "  echo 'Waiting for deletion to propagate...'",
      "  ITER=0",
      "  while curl -s -H 'Authorization: Bearer ${var.authentik_token}' http://${var.leader_address}:9000/api/v3/core/brands/ | grep -q \"$BRAND_ID\"; do",
      "    if [ $ITER -gt 10 ]; then echo 'Timeout waiting for delete'; exit 1; fi",
      "    sleep 2; ITER=$((ITER+1))",
      "  done",
      "fi"
    ]
  }
}

# We then manully insert our own default brand that actually uses the PKI keys we painstakingly setup over the past several hours!
# TODO: We can use this to add some custom branding later on!
resource "authentik_brand" "default" {
  depends_on      = [ null_resource.delete_default_brand ]
  domain          = "authentik.internal"
  branding_title  = "authentik"
  default = true
  # This links the DB record of the cert to the Brand
  web_certificate = authentik_certificate_key_pair.vault_keys.id
}

# Give Authentik some time to settle before running further
resource "time_sleep" "wait_authentik_brand" {
  depends_on = [ authentik_brand.default ]
  create_duration = "20s"
}

resource "random_password" "guac_client_id" {
  length  = 32
  special = false
}

resource "vault_generic_secret" "guac_oidc_creds" {
  path = "secret/guacamole/oidc"
  data_json = jsonencode({
    client_id     = random_password.guac_client_id.result
  })
}

# === Create Guac Login Flow In Authentik ====
# This is the default flow
data "authentik_flow" "default_authorization_flow" {
  depends_on = [ time_sleep.wait_authentik_brand ]
  slug = "default-provider-authorization-implicit-consent"
}
data "authentik_flow" "default_invalidation_flow" {
  depends_on = [ time_sleep.wait_authentik_brand ]
  slug = "default-invalidation-flow"
}
data "vault_generic_secret" "guac_odic_creds" {
  depends_on = [ vault_generic_secret.guac_oidc_creds ]
  path = "secret/guacamole/oidc"
}

# Pull the default scopes needed for Guacamole to authenticate
data "authentik_property_mapping_provider_scope" "scopes" {
  depends_on = [ time_sleep.wait_authentik_brand ]
  managed_list = [
    "goauthentik.io/providers/oauth2/scope-openid",
    "goauthentik.io/providers/oauth2/scope-email",
    "goauthentik.io/providers/oauth2/scope-profile"
  ]
}

# Create OIDC Provider
resource "authentik_provider_oauth2" "guacamole" {
  depends_on = [ time_sleep.wait_authentik_brand ]
  name          = "guacamole"
  client_id     = vault_generic_secret.guac_oidc_creds.data["client_id"]

  authorization_flow = data.authentik_flow.default_authorization_flow.id
  invalidation_flow =  data.authentik_flow.default_invalidation_flow.id
  
  property_mappings = data.authentik_property_mapping_provider_scope.scopes.ids
  sub_mode = "user_username"

  # Add URLS, TODO: make this dynamic using a foreach node
  allowed_redirect_uris = [
    {
      url = "https://guacamole.saruman.internal/",
      matching_mode = "strict"
    },
    {
      url = "https://guacamole.sauron.internal/",
      matching_mode = "strict"
    },
    {
      url = "https://guacamole.smeagol.internal/",
      matching_mode = "strict"
    }
  ]
  # Sign the oauth with the key pair loaded earlier
  signing_key   = authentik_certificate_key_pair.vault_keys.id
}

# Create the Application
resource "authentik_application" "guacamole" {
  depends_on = [ time_sleep.wait_authentik_brand ]
  name              = "Guacamole"
  slug              = "guacamole"
  protocol_provider = authentik_provider_oauth2.guacamole.id
}

# ============================================

resource "nomad_job" "guacamole" {
  jobspec = templatefile("${path.root}/templates/guacamole.hcl.tpl", {})
  # This entire module already depends on postgres-init, but for some reason guac still loads with the previous 
  #depends_on = [ module.postgres-init.null_resource.bootstrap_guac_admin ]
  detach = false
}
