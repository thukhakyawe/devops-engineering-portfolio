Phase 10 — Kubernetes Configuration & Secrets

Next we'll make the application more production-like.

We'll introduce:

                    Application
                         │
             ┌───────────┴───────────┐
             │                       │
          ConfigMap               Secret
             │                       │
      non-sensitive config      sensitive config
             │                       │
             └───────────┬───────────┘
                         ▼
                    Application Pod

We'll specifically practice:

ConfigMap
Kubernetes Secret
environment variable injection
separating configuration from the container image
avoiding hard-coded credentials
Terraform/Kubernetes resource boundaries
Important security rule

We will not put real passwords, API keys, or AWS credentials into Git.

For this project, we'll use safe placeholder/example values while learning the Kubernetes mechanics. Later, when we build the CI/CD and production-security portions, we'll integrate AWS Secrets Manager / External Secrets instead of keeping sensitive values in Terraform state unnecessarily.

Phase 10 structure

Create:

mkdir -p terraform/modules/application-config

Then we'll build:

terraform/modules/application-config/
├── main.tf
├── variables.tf
└── outputs.tf

10A — Create the application configuration module

You already created:

terraform/modules/application-config/
├── main.tf
├── variables.tf
└── outputs.tf

# variables.tf
variable "namespace" {
  description = "Kubernetes namespace for application configuration."
  type        = string
}

variable "environment" {
  description = "Application environment."
  type        = string
}

variable "database_host" {
  description = "Database hostname."
  type        = string
}

variable "database_port" {
  description = "Database port."
  type        = number
  default     = 5432
}

main.tf

Create the non-sensitive configuration as a ConfigMap:

resource "kubernetes_config_map" "application" {
  metadata {
    name      = "platform-api-config"
    namespace = var.namespace
  }

  data = {
    ENVIRONMENT   = var.environment
    DATABASE_HOST = var.database_host
    DATABASE_PORT = tostring(var.database_port)
  }
}

For now, do not create a Kubernetes Secret containing a password.

There's a reason: Kubernetes Secrets are not a substitute for a proper external secret-management system, and values managed directly through Terraform can end up in Terraform state.

We'll address the sensitive-data path separately using AWS Secrets Manager / External Secrets later.

outputs.tf

output "config_map_name" {
  description = "Application ConfigMap name."
  value       = kubernetes_config_map.application.metadata[0].name
}

10B — Connect the module

Add to terraform/main.tf:

module "application_config" {
  source = "./modules/application-config"

  namespace = "application"

  environment = var.environment

  database_host = "postgres.example.internal"

  database_port = 5432
}

Add to terraform/outputs.tf:

output "application_config_map" {
  description = "Application ConfigMap name."
  value       = module.application_config.config_map_name
}

For now, postgres.example.internal is deliberately just an example value. Do not interpret it as a real database endpoint.

10C — Inject the ConfigMap into the application

Now modify:

terraform/modules/application/main.tf

Inside the existing container block, add:

env_from {
  config_map_ref {
    name = "platform-api-config"
  }

So the relevant section becomes:

container {
  name  = var.name
  image = var.image

  port {
    container_port = var.container_port
  }

  env_from {
    config_map_ref {
      name = "platform-api-config"
    }
  }

  resources {
    requests = {
      cpu    = "100m"
      memory = "128Mi"
    }

    limits = {
      cpu    = "250m"
      memory = "256Mi"
    }
  }

  readiness_probe {
    http_get {
      path = "/"
      port = var.container_port
    }

    initial_delay_seconds = 5
    period_seconds        = 10
  }

  liveness_probe {
    http_get {
      path = "/"
      port = var.container_port
    }

    initial_delay_seconds = 10
    period_seconds        = 20
  }

  env {
    name  = "ENVIRONMENT"
    value = "dev"
  }
}

There is a small redundancy here: ENVIRONMENT now comes from both the ConfigMap and the explicit env block. Let's clean that up.

Remove this block:

env {
  name  = "ENVIRONMENT"
  value = "dev"
}

The ConfigMap should be the single source for that non-sensitive configuration.

10D — Validate

Run:

terraform -chdir=terraform fmt -recursive

Then:

terraform -chdir=terraform init

Then:

terraform -chdir=terraform validate

Expected:

Success! The configuration is valid.

Again, do not apply and don't worry if a full plan can't evaluate Kubernetes resources without an actual EKS cluster.

What you've learned in this phase

We're establishing this pattern:

ConfigMap
   │
   ├── ENVIRONMENT
   ├── DATABASE_HOST
   └── DATABASE_PORT
          │
          ▼
     Application Pod

while deliberately keeping:

Passwords
API keys
AWS credentials
database credentials

out of the ConfigMap and out of Git.