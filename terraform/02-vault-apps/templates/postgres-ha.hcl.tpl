job "postgres-ha" {
  datacenters = ["dc1"]
  type        = "system"

  group "database" {
    vault {
      role = "postgres-role"
    }

    network {
      port "patroni-http" {
        static = 8008
      }
      port "postgres-tcp" {
        static = 5432
      }
    }

    # This block MUST be inside the 'group' or 'task' block
    # We put it in the task to ensure the task has access to the destination
    task "patroni" {
      driver = "raw_exec"
      user   = "postgres"

      env {
        HOME = "/var/lib/postgresql"
        # Ensure the system knows where the postgres binaries are
        PATH = "/usr/lib/postgresql/16/bin:/usr/local/bin:/usr/bin:/bin"
      }

      template {
        # Using path relative to where you run nomad command or 
        # inline the content if using Terraform to deploy the job
        data        = <<-EOH
${patroni_yaml}
        EOH
        destination = "local/patroni.yaml"
        change_mode = "restart"
      }

      config {
        command = "/usr/bin/patroni"
        args    = ["local/patroni.yaml"]
      }
    }
  }
}