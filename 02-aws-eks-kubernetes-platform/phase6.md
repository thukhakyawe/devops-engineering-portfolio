Phase 6 — Kubernetes Namespaces

Now we'll start defining the Kubernetes layer.

We'll create three namespaces:

EKS Cluster
│
├── platform
│   └── platform-level components
│
├── application
│   └── application workloads
│
└── monitoring
    └── observability components

This gives us a clean separation before we introduce workloads, Helm, monitoring, and GitOps.

1. Create the Kubernetes namespace module

From the project root:

mkdir -p terraform/modules/namespaces

Create:

terraform/modules/namespaces/
├── main.tf
├── variables.tf
└── outputs.tf

# variables.tf

variable "namespaces" {
  description = "Kubernetes namespaces to create."
  type        = set(string)
}

# main.tf

resource "kubernetes_namespace" "this" {
  for_each = var.namespaces

  metadata {
    name = each.value
  }
}


# outputs.tf

output "namespace_names" {
  description = "Names of the Kubernetes namespaces."
  value       = [
    for namespace in kubernetes_namespace.this : namespace.metadata[0].name
  ]
}

2. Connect the module

Add to terraform/main.tf:

module "namespaces" {
  source = "./modules/namespaces"

  namespaces = [
    "platform",
    "application",
    "monitoring"
  ]
}

Add to terraform/outputs.tf:

output "kubernetes_namespaces" {
  description = "Kubernetes namespaces managed by Terraform."
  value       = module.namespaces.namespace_names
}

3. Format and validate

Run:

terraform -chdir=terraform fmt -recursive

Then:

terraform -chdir=terraform init
terraform -chdir=terraform validate

Important: don't run plan for this phase

Because the Kubernetes cluster doesn't actually exist in AWS yet, the Kubernetes provider cannot connect to the API server and create/read these namespaces.

We already established that the Terraform configuration is valid.

So for now, our success criterion is:

Success! The configuration is valid.

This is an important distinction in our no-apply learning workflow:

Terraform AWS resources
        │
        ▼
      PLAN
        │
        └── Can evaluate without creating AWS resources


Kubernetes resources
        │
        ▼
 Kubernetes API
        │
        └── Requires a real EKS cluster

We're therefore going to build the complete project first, validate everything we can statically, and not incur AWS costs just for learning the workflow.