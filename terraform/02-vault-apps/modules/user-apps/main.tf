# Run Authentik Init job
resource "nomad_job" "authentik-bootstrap" {
  jobspec = templatefile("${path.root}/templates/authentik-bootstrap.hcl.tpl", {})
  detach = false
}
# Wait for the batch job to exit before starting the rest of Authentik
# Even when depends_on authentik-bootstrap, terraform does not wait for the job to actually be completed, just registered
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
  detach = false
}

# ============================================

resource "nomad_job" "guacamole" {
  jobspec = templatefile("${path.root}/templates/guacamole.hcl.tpl", {})
  # This entire module already depends on postgres-init, but for some reason guac still loads with the previous 
  #depends_on = [ module.postgres-init.null_resource.bootstrap_guac_admin ]
  detach = false
}
