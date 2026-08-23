Phase 12 — Kubernetes Deployment Hardening

This phase is important because we're moving from a workload that merely runs to one that demonstrates production-oriented Kubernetes practices.

We will add:

security context
non-root execution
resource requests/limits
startup probe
readiness probe
liveness probe
rolling-update strategy
PodDisruptionBudget

We still will not run terraform apply.

Phase 12A — Harden the application Deployment

Open:

terraform/modules/application/main.tf

1. Add a Pod-level security context

Inside:

resource "kubernetes_deployment" "this"

add:

spec {
  security_context {
    run_as_non_root = true
    seccomp_profile {
      type = "RuntimeDefault"
    }
  }

So the Deployment structure should look roughly like:

resource "kubernetes_deployment" "this" {
  metadata {
    name      = var.name
    namespace = var.namespace
  }

  spec {
    replicas = var.replicas

    security_context {
      run_as_non_root = true

      seccomp_profile {
        type = "RuntimeDefault"
      }
    }

    # existing selector/template...
  }
}

Phase 12B — Harden the container

Inside your existing:

container {
  name  = var.name
  image = var.image

add:

security_context {
  allow_privilege_escalation = false
  privileged                 = false
  read_only_root_filesystem  = true

  capabilities {
    drop = ["ALL"]
  }
}

So:

container {
  name  = var.name
  image = var.image

  security_context {
    allow_privilege_escalation = false
    privileged                 = false
    read_only_root_filesystem  = true

    capabilities {
      drop = ["ALL"]
    }
  }

  port {
    container_port = var.container_port
  }

  ...
}

Important caveat

read_only_root_filesystem = true is a good security control, but the application image must actually support it.

If the application writes to /tmp or another location in the container filesystem, we'll need to provide an emptyDir volume later.

For this project, we'll first enforce the hardened configuration and test it when the workload is actually deployed.

Phase 12C — Resource requests and limits

You already have resource configuration, but let's make the policy explicit.

Inside container:

resources {
  requests = {
    cpu    = "100m"
    memory = "128Mi"
  }

  limits = {
    cpu    = "500m"
    memory = "512Mi"
  }
}

This gives Kubernetes information for scheduling:

Requests
────────
CPU:    100m
Memory: 128Mi

Limits
──────
CPU:    500m
Memory: 512Mi

This becomes particularly important later when we introduce Horizontal Pod Autoscaling.

Phase 12D — Add a startup probe

A startup probe prevents Kubernetes from killing an application that simply needs more time to initialize.

Add:

startup_probe {
  http_get {
    path = "/"
    port = var.container_port
  }

  failure_threshold = 30
  period_seconds    = 5
}

This gives the application up to approximately:

30 × 5 seconds = 150 seconds

to start successfully.

Phase 12E — Improve readiness and liveness

Keep your existing probes, but use:

readiness_probe {
  http_get {
    path = "/"
    port = var.container_port
  }

  initial_delay_seconds = 5
  period_seconds        = 10
  timeout_seconds       = 2
  failure_threshold     = 3
  success_threshold     = 1
}

liveness_probe {
  http_get {
    path = "/"
    port = var.container_port
  }

  initial_delay_seconds = 15
  period_seconds        = 20
  timeout_seconds       = 2
  failure_threshold     = 3
  success_threshold     = 1
}

The distinction is important:

Startup
   │
   └── "Has the application started?"

Readiness
   │
   └── "Can this Pod receive traffic?"

Liveness
   │
   └── "Is this Pod still healthy?"

Phase 12F — Rolling update strategy

Inside the existing Deployment spec, immediately after:

replicas = var.replicas

add:

strategy {
  type = "RollingUpdate"

  rolling_update {
    max_unavailable = "25%"
    max_surge       = "25%"
  }
}

This means Kubernetes can progressively replace Pods rather than taking the entire application down.

Architecture:

Old Pods
  │
  ├── Pod A
  └── Pod B

       ↓ deployment

New Pods
  │
  ├── Pod A
  ├── Pod B
  └── Pod C
       │
       ▼
Old Pods gradually removed

Phase 12G — PodDisruptionBudget

Create:

terraform/modules/application/pdb.tf

Add:

resource "kubernetes_pod_disruption_budget_v1" "this" {
  metadata {
    name      = "${var.name}-pdb"
    namespace = var.namespace
  }

  spec {
    min_available = 1

    selector {
      match_labels = {
        app = var.name
      }
    }
  }
}

This protects the application during voluntary disruptions, such as node maintenance or cluster operations.

Phase 12H — Make the selector match

Make sure your Deployment's Pod labels contain:

labels = {
  app = var.name
}

and the Deployment selector contains:

selector {
  match_labels = {
    app = var.name
  }
}

The PDB depends on those labels matching.

Phase 12I — Validate

Now run:

terraform -chdir=terraform fmt -recursive

Then:

terraform -chdir=terraform init

Then:

terraform -chdir=terraform validate

Expected:

Success! The configuration is valid.
Don't apply

We're still keeping the entire project in the design/validation stage:

terraform apply
        ❌

Phase 12 outcome

After this phase, your application demonstrates substantially stronger Kubernetes practices:

                    Deployment
                        │
          ┌─────────────┼─────────────┐
          │             │             │
       Security      Resources      Probes
          │             │             │
     non-root       requests/       startup
     no privilege   limits          readiness
     no capabilities                liveness
          │
          └─────────────┬─────────────┘
                        │
                 Rolling Update
                        │
                        ▼
                 PodDisruptionBudget

Project 2 progression
01 Networking                         ✅
02 EKS IAM                            ✅
03 EKS Control Plane                  ✅
04 Managed Node Group                 ✅
05 Kubernetes Provider                ✅
06 Namespaces                         ✅
07 Application                        ✅
08 AWS Load Balancer Controller       ✅
09 Ingress → ALB                      ✅
10 ConfigMap                          ✅
11 Secrets Manager / External Secrets ✅
12 Deployment Hardening               ← NOW