Phase 8 — AWS Load Balancer Controller Foundation

We'll prepare the project for:

Internet
    │
    ▼
AWS Application Load Balancer
    │
    ▼
AWS Load Balancer Controller
    │
    ▼
Kubernetes Service / Ingress
    │
    ▼
platform-api Pods

This is an important DevOps skill because it connects:

AWS infrastructure → Kubernetes → AWS networking → application delivery.

We'll build this in two pieces:

8A — Controller IAM

Create the IAM role/policy required by the AWS Load Balancer Controller.

8B — Helm installation

We'll later deploy the controller using Helm rather than treating it as a normal Kubernetes Deployment.

That introduces another important technology into the portfolio:

Terraform
   │
   ├── AWS infrastructure
   │
   └── IAM
          │
          ▼
       EKS
          │
          ├── Helm
          │
          └── Kubernetes
First: create the controller module

Run:

mkdir -p terraform/modules/aws-load-balancer-controller

Create:

terraform/modules/aws-load-balancer-controller/
├── main.tf
├── variables.tf
└── outputs.tf

# variables.tf

variable "name" {
  description = "Name prefix for AWS Load Balancer Controller resources."
  type        = string
}

variable "tags" {
  description = "Tags applied to IAM resources."
  type        = map(string)
  default     = {}
}


# main.tf

For this phase, create the IAM role and the Pod Identity association:

data "aws_iam_policy_document" "controller_assume_role" {
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

resource "aws_iam_role" "controller" {
  name               = "${var.name}-aws-lbc-role"
  assume_role_policy = data.aws_iam_policy_document.controller_assume_role.json

  tags = merge(
    var.tags,
    {
      Name = "${var.name}-aws-lbc-role"
    }
  )
}

resource "aws_eks_pod_identity_association" "controller" {
  cluster_name    = var.name
  namespace       = "kube-system"
  service_account = "aws-load-balancer-controller"
  role_arn        = aws_iam_role.controller.arn
}

# outputs.tf

output "role_arn" {
  description = "IAM role ARN used by the AWS Load Balancer Controller."
  value       = aws_iam_role.controller.arn
}

output "role_name" {
  description = "IAM role name used by the AWS Load Balancer Controller."
  value       = aws_iam_role.controller.name
}

Important

There is one more component we will add in the next step: the AWS Load Balancer Controller IAM policy.

I'm deliberately separating that from the role/Pod Identity association so you can understand the AWS authorization model instead of treating the whole thing as a copy-paste block.

2. Connect the module

Add this to terraform/main.tf:

module "aws_load_balancer_controller" {
  source = "./modules/aws-load-balancer-controller"

  name = module.eks.cluster_name

  tags = {
    Environment = var.environment
  }
}

Add to terraform/outputs.tf:

output "aws_load_balancer_controller_role_arn" {
  description = "IAM role ARN for the AWS Load Balancer Controller."
  value       = module.aws_load_balancer_controller.role_arn
}

3. Format and validate

Run:

terraform -chdir=terraform fmt -recursive

Then:

terraform -chdir=terraform init

Then:

terraform -chdir=terraform validate

You should get:

Success! The configuration is valid.
Don't run plan yet

The new resource:

aws_eks_pod_identity_association

is tied to the actual EKS cluster. Since we deliberately haven't created the cluster, a complete plan involving this association cannot be meaningfully executed against AWS.

---

Phase 8B — AWS Load Balancer Controller IAM Policy

Now we need to give the controller the AWS permissions it actually needs.

The architecture is:

                    EKS
                     │
                     ▼
       AWS Load Balancer Controller
                     │
              Pod Identity
                     │
                     ▼
              IAM Role
                     │
                     ▼
              IAM Policy
                     │
       ┌─────────────┼─────────────┐
       ▼             ▼             ▼
      ALB          Target        Security
                  Groups          Groups

1. Add the policy to the module

Open:

terraform/modules/aws-load-balancer-controller/main.tf

Keep what you already have and add this after the role:

data "aws_iam_policy_document" "controller_permissions" {
  statement {
    effect = "Allow"

    actions = [
      "iam:CreateServiceLinkedRole"
    ]

    resources = ["*"]

    condition {
      test     = "StringEquals"
      variable = "iam:AWSServiceName"

      values = [
        "elasticloadbalancing.amazonaws.com"
      ]
    }
  }

  statement {
    effect = "Allow"

    actions = [
      "ec2:DescribeAccountAttributes",
      "ec2:DescribeAddresses",
      "ec2:DescribeAvailabilityZones",
      "ec2:DescribeInternetGateways",
      "ec2:DescribeVpcs",
      "ec2:DescribeSubnets",
      "ec2:DescribeSecurityGroups",
      "ec2:DescribeInstances",
      "ec2:DescribeNetworkInterfaces",
      "ec2:DescribeTags",
      "ec2:GetCoipPoolUsage",
      "ec2:GetSecurityGroupsForVpc",
      "ec2:DescribeCoipPools"
    ]

    resources = ["*"]
  }

  statement {
    effect = "Allow"

    actions = [
      "elasticloadbalancing:DescribeLoadBalancers",
      "elasticloadbalancing:DescribeLoadBalancerAttributes",
      "elasticloadbalancing:DescribeListeners",
      "elasticloadbalancing:DescribeListenerAttributes",
      "elasticloadbalancing:DescribeListenerCertificates",
      "elasticloadbalancing:DescribeSSLPolicies",
      "elasticloadbalancing:DescribeRules",
      "elasticloadbalancing:DescribeTargetGroups",
      "elasticloadbalancing:DescribeTargetHealth",
      "elasticloadbalancing:DescribeTags"
    ]

    resources = ["*"]
  }

  statement {
    effect = "Allow"

    actions = [
      "cognito-idp:DescribeUserPoolClient",
      "acm:ListCertificates",
      "acm:DescribeCertificate",
      "iam:ListServerCertificates",
      "iam:GetServerCertificate",
      "waf-regional:GetWebACL",
      "waf-regional:GetWebACLForResource",
      "waf-regional:AssociateWebACL",
      "waf-regional:DisassociateWebACL",
      "wafv2:GetWebACL",
      "wafv2:GetWebACLForResource",
      "wafv2:AssociateWebACL",
      "wafv2:DisassociateWebACL",
      "shield:GetSubscriptionState",
      "shield:DescribeProtection",
      "shield:CreateProtection",
      "shield:DeleteProtection"
    ]

    resources = ["*"]
  }

  statement {
    effect = "Allow"

    actions = [
      "elasticloadbalancing:CreateLoadBalancer",
      "elasticloadbalancing:CreateTargetGroup",
      "elasticloadbalancing:CreateListener",
      "elasticloadbalancing:DeleteLoadBalancer",
      "elasticloadbalancing:DeleteTargetGroup",
      "elasticloadbalancing:DeleteListener",
      "elasticloadbalancing:ModifyLoadBalancerAttributes",
      "elasticloadbalancing:ModifyTargetGroup",
      "elasticloadbalancing:ModifyTargetGroupAttributes",
      "elasticloadbalancing:ModifyListener",
      "elasticloadbalancing:AddTags",
      "elasticloadbalancing:RemoveTags",
      "elasticloadbalancing:AddListenerCertificates",
      "elasticloadbalancing:RemoveListenerCertificates",
      "elasticloadbalancing:ModifyListenerAttributes"
    ]

    resources = ["*"]
  }

  statement {
    effect = "Allow"

    actions = [
      "ec2:AuthorizeSecurityGroupIngress",
      "ec2:RevokeSecurityGroupIngress"
    ]

    resources = ["*"]
  }

  statement {
    effect = "Allow"

    actions = [
      "ec2:CreateSecurityGroup"
    ]

    resources = ["*"]
  }

  statement {
    effect = "Allow"

    actions = [
      "ec2:CreateTags"
    ]

    resources = [
      "arn:aws:ec2:*:*:security-group/*"
    ]
  }

  statement {
    effect = "Allow"

    actions = [
      "ec2:DeleteTags"
    ]

    resources = [
      "arn:aws:ec2:*:*:security-group/*"
    ]
  }

  statement {
    effect = "Allow"

    actions = [
      "elasticloadbalancing:SetWebAcl",
      "elasticloadbalancing:ModifyRule",
      "elasticloadbalancing:AddTags"
    ]

    resources = ["*"]
  }
}

resource "aws_iam_policy" "controller" {
  name        = "${var.name}-aws-lbc-policy"
  description = "Permissions for AWS Load Balancer Controller."

  policy = data.aws_iam_policy_document.controller_permissions.json

  tags = merge(
    var.tags,
    {
      Name = "${var.name}-aws-lbc-policy"
    }
  )
}

resource "aws_iam_role_policy_attachment" "controller" {
  role       = aws_iam_role.controller.name
  policy_arn = aws_iam_policy.controller.arn
}

Add the policy output

In outputs.tf, add:

output "policy_arn" {
  description = "IAM policy ARN used by the AWS Load Balancer Controller."
  value       = aws_iam_policy.controller.arn
}

2. Validate again

Run:

terraform -chdir=terraform fmt -recursive

Then:

terraform -chdir=terraform init

Then:

terraform -chdir=terraform validate

Expected:

Success! The configuration is valid.

Don't apply.

---

Phase 8C — Helm

Now we'll introduce Helm, which is an important Kubernetes skill for your DevOps portfolio.

The eventual architecture will be:

Terraform
   │
   ├── AWS infrastructure
   │
   └── EKS
        │
        └── Helm
             │
             └── AWS Load Balancer Controller
                    │
                    ▼
                   AWS
                    │
              Application
              Load Balancer
                    │
                    ▼
              Kubernetes Service
                    │
                    ▼
              platform-api Pods

But there's an important issue

Because your EKS cluster doesn't exist yet, we cannot actually install a Helm release into it.

So we're going to prepare the Terraform configuration, validate what can be validated, and not apply.

1. Add the Helm provider

Open:

terraform/versions.tf

Add:

helm = {
  source  = "hashicorp/helm"
  version = "~> 3.0"
}

Your providers should now include:

required_providers {
  aws = {
    source  = "hashicorp/aws"
    version = "~> 6.0"
  }

  kubernetes = {
    source  = "hashicorp/kubernetes"
    version = "~> 2.38"
  }

  helm = {
    source  = "hashicorp/helm"
    version = "~> 3.0"
  }
}

2. Initialize

Run:
terraform -chdir=terraform fmt -recursive

Then:

terraform -chdir=terraform init

Terraform should install the Helm provider.

Then:

terraform -chdir=terraform validate

Expected:

Success! The configuration is valid.

Stop there for now.

Don't add the Helm release yet. Once we confirm the Helm provider initializes correctly, we'll configure its connection to EKS and then add the AWS Load Balancer Controller chart.

This keeps each layer understandable:

Terraform
   ↓
AWS
   ↓
EKS
   ↓
Kubernetes Provider
   ↓
Helm Provider
   ↓
AWS Load Balancer Controller

---

Next: Phase 8D — Helm + AWS Load Balancer Controller

Before we install the controller, we're going to configure the Helm provider to authenticate against the EKS cluster.

However, because we are intentionally not running terraform apply, we won't attempt to install the Helm release yet.

We'll first add the provider configuration.

Create:

terraform/helm.tf

with:

data "aws_eks_cluster" "helm" {
  name = module.eks.cluster_name
}

data "aws_eks_cluster_auth" "helm" {
  name = module.eks.cluster_name
}

provider "helm" {
  kubernetes = {
    host                   = data.aws_eks_cluster.helm.endpoint
    cluster_ca_certificate = base64decode(
      data.aws_eks_cluster.helm.certificate_authority[0].data
    )

    token = data.aws_eks_cluster_auth.helm.token
  }
}

Then format:

terraform -chdir=terraform fmt -recursive

And validate:

terraform -chdir=terraform init

Then:
terraform -chdir=terraform validate

Expected:

Success! The configuration is valid.
Don't add the Helm release yet

We'll add the actual:

helm_release

only after the provider configuration is validated.

That gives us a clean progression:

Phase 8A
IAM Role + Pod Identity
        ↓
Phase 8B
IAM Policy
        ↓
Phase 8C
Helm Provider
        ↓
Phase 8D
Helm → EKS authentication
        ↓
Phase 8E
AWS Load Balancer Controller
        ↓
Phase 9
Ingress → AWS ALB

---

Phase 8E — AWS Load Balancer Controller

Now we'll define the actual Helm release.

The controller will eventually provide this path:

Internet
   │
   ▼
AWS Application Load Balancer
   │
   ▼
AWS Load Balancer Controller
   │
   ▼
Kubernetes Ingress
   │
   ▼
Service
   │
   ▼
platform-api
   │
   ├── Pod
   └── Pod

1. Add the Helm release

Open:

terraform/modules/aws-load-balancer-controller/main.tf

At this point, don't add the Helm release inside that module.

Instead, create:

terraform/aws-load-balancer-controller.tf

Add:

resource "helm_release" "aws_load_balancer_controller" {
  name       = "aws-load-balancer-controller"
  namespace  = "kube-system"
  repository = "https://aws.github.io/eks-charts"
  chart      = "aws-load-balancer-controller"

  create_namespace = false

  set = [
    {
      name  = "clusterName"
      value = module.eks.cluster_name
    },
    {
      name  = "serviceAccount.create"
      value = "true"
    },
    {
      name  = "serviceAccount.name"
      value = "aws-load-balancer-controller"
    },
    {
      name  = "region"
      value = var.aws_region
    },
    {
      name  = "vpcId"
      value = module.networking.vpc_id
    }
  ]

  depends_on = [
    module.aws_load_balancer_controller
  ]
}

Why depends_on?

We want Terraform's dependency graph to make the relationship explicit:

EKS
 │
 ▼
Pod Identity / IAM
 │
 ▼
Helm Release

2. Important correction before you validate

We currently have two different mechanisms involved:

IAM
 │
 └── Pod Identity association
       └── service account:
           aws-load-balancer-controller

Helm
 │
 └── serviceAccount.create = true

That's not ideal.

Since we're using EKS Pod Identity, the Kubernetes service account should be created by Helm, while AWS authorization comes from the Pod Identity association.

That's actually what we're doing here, so this is intentional.

The important part is that the names match exactly:

IAM Pod Identity:
aws-load-balancer-controller

Helm:
aws-load-balancer-controller

3. Format

Run:

terraform -chdir=terraform fmt -recursive

Then:

terraform -chdir=terraform init

Then:
terraform -chdir=terraform validate
Do NOT run plan

At this point the helm_release requires a reachable Kubernetes API server.

Because your EKS cluster hasn't been created:

EKS cluster
    ❌ not actually running

so a real Helm deployment cannot happen yet.

Our validation checkpoint remains:

Success! The configuration is valid.

Where we are now

Project 2 — AWS EKS + Kubernetes Platform

AWS Layer
├── VPC                         ✅
├── Subnets                     ✅
├── NAT                         ✅
├── EKS IAM                    ✅
├── EKS Control Plane           ✅
└── Managed Node Group          ✅

Kubernetes Layer
├── Kubernetes provider         ✅
├── Namespaces                  ✅
├── Application Deployment      ✅
└── Application Service         ✅

AWS/Kubernetes Integration
├── LBC IAM Role                ✅
├── EKS Pod Identity            ✅
├── LBC IAM Policy              ✅
├── Helm provider               ✅
├── Helm → EKS authentication   ✅
└── LBC Helm release            ← **now**