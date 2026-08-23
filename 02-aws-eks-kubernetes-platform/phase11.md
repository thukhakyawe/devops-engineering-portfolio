Phase 11 — AWS Secrets Manager → Kubernetes

This is an important step because we're moving from:

ConfigMap
  └── non-sensitive configuration

to:

AWS Secrets Manager
        │
        ▼
External Secrets Operator
        │
        ▼
Kubernetes Secret
        │
        ▼
Application Pod

This is much closer to a production platform pattern.

11A — Create the External Secrets IAM module

Create:

mkdir -p terraform/modules/external-secrets

Create:

terraform/modules/external-secrets/
├── main.tf
├── variables.tf
└── outputs.tf

# variables.tf
variable "name" {
  description = "Name prefix for External Secrets resources."
  type        = string
}

variable "tags" {
  description = "Tags applied to IAM resources."
  type        = map(string)
  default     = {}
}

# main.tf

We'll give External Secrets access only to the Secrets Manager secrets it needs.

data "aws_iam_policy_document" "assume_role" {
  statement {
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["pods.eks.amazonaws.com"]
    }

    actions = [
      "sts:AssumeRole",
      "sts:TagSession"
    ]
  }
}

resource "aws_iam_role" "external_secrets" {
  name               = "${var.name}-external-secrets-role"
  assume_role_policy = data.aws_iam_policy_document.assume_role.json

  tags = merge(
    var.tags,
    {
      Name = "${var.name}-external-secrets-role"
    }
  )
}

resource "aws_iam_policy" "external_secrets" {
  name        = "${var.name}-external-secrets-policy"
  description = "Allow External Secrets Operator to read AWS Secrets Manager secrets."

  policy = jsonencode({
    Version = "2012-10-17"

    Statement = [
      {
        Effect = "Allow"

        Action = [
          "secretsmanager:GetSecretValue",
          "secretsmanager:DescribeSecret"
        ]

        Resource = "arn:aws:secretsmanager:*:*:secret:${var.name}/*"
      }
    ]
  })

  tags = var.tags
}

resource "aws_iam_role_policy_attachment" "external_secrets" {
  role       = aws_iam_role.external_secrets.name
  policy_arn = aws_iam_policy.external_secrets.arn
}

resource "aws_eks_pod_identity_association" "external_secrets" {
  cluster_name    = var.name
  namespace       = "external-secrets"
  service_account = "external-secrets"
  role_arn        = aws_iam_role.external_secrets.arn
}

# outputs.tf

output "role_arn" {
  description = "IAM role ARN for External Secrets Operator."
  value       = aws_iam_role.external_secrets.arn
}

output "role_name" {
  description = "IAM role name for External Secrets Operator."
  value       = aws_iam_role.external_secrets.name
}

output "policy_arn" {
  description = "IAM policy ARN for External Secrets Operator."
  value       = aws_iam_policy.external_secrets.arn
}

11B — Connect the module

In:

terraform/main.tf

add:

module "external_secrets" {
  source = "./modules/external-secrets"

  name = module.eks.cluster_name

  tags = {
    Environment = var.environment
  }
}

In:

terraform/outputs.tf

add:

output "external_secrets_role_arn" {
  description = "IAM role ARN for External Secrets Operator."
  value       = module.external_secrets.role_arn
}

11C — Create the AWS Secrets Manager secret

We'll create a dev-only example secret. Do not put a real production password into the repository.

Create:

terraform/secrets.tf

with:

resource "aws_secretsmanager_secret" "application" {
  name = "${var.environment}/platform-api/database"

  description = "Database credentials for the platform API."

  tags = {
    Environment = var.environment
    Application = "platform-api"
  }
}

For now, do not create aws_secretsmanager_secret_version with a real password.

That's intentional.

The project should demonstrate the architecture without teaching you to commit secret values into Terraform configuration.

11D — Helm External Secrets Operator

Create:

terraform/external-secrets.tf

with:

resource "helm_release" "external_secrets" {
  name       = "external-secrets"
  namespace  = "external-secrets"
  repository = "https://charts.external-secrets.io"
  chart      = "external-secrets"

  create_namespace = true

  set = [
    {
      name  = "installCRDs"
      value = "true"
    },
    {
      name  = "serviceAccount.create"
      value = "true"
    },
    {
      name  = "serviceAccount.name"
      value = "external-secrets"
    }
  ]

  depends_on = [
    module.external_secrets
  ]
}

This gives us:

EKS
 │
 ├── external-secrets namespace
 │
 └── External Secrets Operator
          │
          ▼
   AWS Secrets Manager

11E — Create the ExternalSecret

Now create:

terraform/modules/application-config/external-secret.tf

resource "kubernetes_manifest" "database_secret" {
  manifest = {
    apiVersion = "external-secrets.io/v1beta1"
    kind       = "ExternalSecret"

    metadata = {
      name      = "platform-api-database"
      namespace = var.namespace
    }

    spec = {
      refreshInterval = "1h"

      secretStoreRef = {
        name = "aws-secretsmanager"
        kind = "ClusterSecretStore"
      }

      target = {
        name           = "platform-api-database"
        creationPolicy = "Owner"
      }

      data = [
        {
          secretKey = "username"

          remoteRef = {
            key      = "${var.environment}/platform-api/database"
            property = "username"
          }
        },
        {
          secretKey = "password"

          remoteRef = {
            key      = "${var.environment}/platform-api/database"
            property = "password"
          }
        }
      ]
    }
  }
}

We need one more resource: the ClusterSecretStore.

Otherwise the ExternalSecret refers to something that doesn't exist:

ExternalSecret
      │
      ▼
ClusterSecretStore
      │
      ▼
AWS Secrets Manager

We'll create that next.

Phase 11 checkpoint

The architecture we're building is:

                    AWS
                     │
             ┌───────▼────────┐
             │ Secrets Manager│
             └───────┬────────┘
                     │
               IAM / Pod Identity
                     │
                     ▼
             External Secrets
                Operator
                     │
                     ▼
             ClusterSecretStore
                     │
                     ▼
             Kubernetes Secret
                     │
                     ▼
              platform-api Pod

This is the missing link between External Secrets Operator and AWS Secrets Manager.

11F — Add the ClusterSecretStore

Create:

terraform/modules/application-config/secret-store.tf

Add:

resource "kubernetes_manifest" "aws_secrets_manager_store" {
  manifest = {
    apiVersion = "external-secrets.io/v1beta1"
    kind       = "ClusterSecretStore"

    metadata = {
      name = "aws-secretsmanager"
    }

    spec = {
      provider = {
        aws = {
          service = "SecretsManager"
          region  = var.aws_region

          auth = {
            jwt = {
              serviceAccountRef = {
                name      = "external-secrets"
                namespace = "external-secrets"
              }
            }
          }
        }
      }
    }
  }
}

Important

Our current application-config module does not yet have aws_region.

Add this to:

terraform/modules/application-config/variables.tf

variable "aws_region" {
  description = "AWS region used by Secrets Manager."
  type        = string
}

Then update the module call in:

terraform/main.tf

Add:

aws_region = var.aws_region

So the module should now have:

module "application_config" {
  source = "./modules/application-config"

  namespace = "application"

  environment = var.environment

  database_host = "postgres.example.internal"

  database_port = 5432

  aws_region = var.aws_region
}

11G — One architecture issue to fix

There's one important detail in the previous step: the External Secrets Operator Helm release creates the external-secrets service account, while the Pod Identity association is configured for that same service account.

That's correct.

But the ClusterSecretStore should only be created after External Secrets Operator and its CRDs are available.

Therefore, add this dependency to terraform/modules/application-config/secret-store.tf

depends_on = [
  helm_release.external_secrets
]

So the complete resource becomes:

resource "kubernetes_manifest" "aws_secrets_manager_store" {
  manifest = {
    apiVersion = "external-secrets.io/v1beta1"
    kind       = "ClusterSecretStore"

    metadata = {
      name = "aws-secretsmanager"
    }

    spec = {
      provider = {
        aws = {
          service = "SecretsManager"
          region  = var.aws_region

          auth = {
            jwt = {
              serviceAccountRef = {
                name      = "external-secrets"
                namespace = "external-secrets"
              }
            }
          }
        }
      }
    }
  }

  depends_on = [
    helm_release.external_secrets
  ]
}

One more thing

The configuration above uses the JWT/IRSA-style authentication block, while earlier we deliberately chose EKS Pod Identity.

We should not mix those two authentication mechanisms.

So before you run validation, let's correct this design rather than building a hybrid configuration.

For this project, we're using:

EKS Pod Identity
        │
        ▼
external-secrets ServiceAccount
        │
        ▼
IAM Role
        │
        ▼
Secrets Manager

Therefore, don't run fmt/init/validate yet.

Next we'll change the ClusterSecretStore to the correct authentication model for Pod Identity and then validate the entire Phase 11 configuration.

11F — Correct ClusterSecretStore

Replace the contents of:

terraform/modules/application-config/secret-store.tf

with:

resource "kubernetes_manifest" "aws_secrets_manager_store" {
  manifest = {
    apiVersion = "external-secrets.io/v1beta1"
    kind       = "ClusterSecretStore"

    metadata = {
      name = "aws-secretsmanager"
    }

    spec = {
      provider = {
        aws = {
          service = "SecretsManager"
          region  = var.aws_region
        }
      }
    }
  }

  depends_on = [
    helm_release.external_secrets
  ]
}

But there's another dependency issue: helm_release.external_secrets is defined in the root module, while application-config is a child module.

A child module cannot directly reference a root-module resource like:

helm_release.external_secrets

So don't use that depends_on inside the module.

Use this instead:

resource "kubernetes_manifest" "aws_secrets_manager_store" {
  manifest = {
    apiVersion = "external-secrets.io/v1beta1"
    kind       = "ClusterSecretStore"

    metadata = {
      name = "aws-secretsmanager"
    }

    spec = {
      provider = {
        aws = {
          service = "SecretsManager"
          region  = var.aws_region
        }
      }
    }
  }
}

Then we'll establish the dependency at the root module.

Phase 11G — Add the dependency correctly

In terraform/main.tf, update the application_config module:

module "application_config" {
  source = "./modules/application-config"

  namespace = "application"

  environment = var.environment

  database_host = "postgres.example.internal"

  database_port = 5432

  aws_region = var.aws_region

  depends_on = [
    helm_release.external_secrets
  ]
}

This gives Terraform the correct dependency graph:

EKS
 │
 ├── External Secrets IAM
 │
 ├── External Secrets Helm
 │
 └── application-config
       │
       ├── ClusterSecretStore
       │
       └── ExternalSecret

Phase 11H — Fix the ExternalSecret dependency

Your existing:

terraform/modules/application-config/external-secret.tf

should remain:

resource "kubernetes_manifest" "database_secret" {
  manifest = {
    apiVersion = "external-secrets.io/v1beta1"
    kind       = "ExternalSecret"

    metadata = {
      name      = "platform-api-database"
      namespace = var.namespace
    }

    spec = {
      refreshInterval = "1h"

      secretStoreRef = {
        name = "aws-secretsmanager"
        kind = "ClusterSecretStore"
      }

      target = {
        name           = "platform-api-database"
        creationPolicy = "Owner"
      }

      data = [
        {
          secretKey = "username"

          remoteRef = {
            key      = "${var.environment}/platform-api/database"
            property = "username"
          }
        },
        {
          secretKey = "password"

          remoteRef = {
            key      = "${var.environment}/platform-api/database"
            property = "password"
          }
        }
      ]
    }
  }
}

Because the whole application_config module depends on:

helm_release.external_secrets

both the ClusterSecretStore and ExternalSecret will be ordered after the operator installation.

Phase 11I — Validate everything

Now run:

terraform -chdir=terraform fmt -recursive

Then:

terraform -chdir=terraform init

Then:

terraform -chdir=terraform validate

Expected:

Success! The configuration is valid.

One important caveat

There is still an architectural limitation we need to address before applying this project:

The AWS provider's EKS Pod Identity association gives the IAM role to the Kubernetes service account, but the ClusterSecretStore AWS provider itself does not need an explicit JWT configuration.

The intended runtime path is:

External Secrets Operator Pod
        │
        │ ServiceAccount:
        │ external-secrets
        ▼
EKS Pod Identity
        │
        ▼
IAM Role
        │
        ▼
secretsmanager:GetSecretValue
        │
        ▼
AWS Secrets Manager

That's the model we're practicing.