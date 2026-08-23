Phase 14 — EKS Node Autoscaling.

This phase is important because we need to distinguish two different scaling layers:

                    Traffic / CPU
                         │
                         ▼
                       HPA
                         │
                  scales Pods
                         │
             ┌───────────┴───────────┐
             ▼                       ▼
          Pod Pod                  Pod Pod
             │                       │
             └──────────┬────────────┘
                        │
                 insufficient
                  node capacity
                        │
                        ▼
                Node Autoscaling
                        │
                        ▼
                 EKS Node Group

HPA scales Pods. Node autoscaling scales the compute capacity that runs those Pods.

For this project, however, we should make one architectural improvement: do not introduce the old Kubernetes Cluster Autoscaler unless we specifically want to learn it. For a modern EKS platform, we'll use Karpenter as the node provisioning layer.

That gives us:

HPA
 │
 ├── Pod count increases
 │
 ▼
Pending Pods
 │
 ▼
Karpenter
 │
 ▼
EC2 capacity

And this is a strong DevOps/Kubernetes skill to demonstrate.

Phase 14A — Karpenter IAM

Create:

mkdir -p terraform/modules/karpenter

Create:

terraform/modules/karpenter/
├── main.tf
├── variables.tf
└── outputs.tf

# variables.tf

variable "cluster_name" {
  description = "EKS cluster name."
  type        = string
}

variable "node_role_arn" {
  description = "IAM role ARN used by EKS worker nodes."
  type        = string
}

variable "tags" {
  description = "Tags applied to Karpenter resources."
  type        = map(string)
  default     = {}
}

Phase 14B — Karpenter controller IAM role

Create:

terraform/modules/karpenter/main.tf

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

resource "aws_iam_role" "controller" {
  name               = "${var.cluster_name}-karpenter-controller"
  assume_role_policy = data.aws_iam_policy_document.assume_role.json

  tags = merge(
    var.tags,
    {
      Name = "${var.cluster_name}-karpenter-controller"
    }
  )
}

# Now add the controller permissions:

data "aws_iam_policy_document" "controller" {
  statement {
    effect = "Allow"

    actions = [
      "ec2:CreateFleet",
      "ec2:CreateLaunchTemplate",
      "ec2:CreateTags",
      "ec2:DescribeAvailabilityZones",
      "ec2:DescribeImages",
      "ec2:DescribeInstances",
      "ec2:DescribeInstanceTypes",
      "ec2:DescribeLaunchTemplates",
      "ec2:DescribeSecurityGroups",
      "ec2:DescribeSpotPriceHistory",
      "ec2:DescribeSubnets",
      "ec2:RunInstances",
      "ec2:TerminateInstances"
    ]

    resources = ["*"]
  }

  statement {
    effect = "Allow"

    actions = [
      "iam:PassRole"
    ]

    resources = [
      var.node_role_arn
    ]
  }
}

resource "aws_iam_policy" "controller" {
  name        = "${var.cluster_name}-karpenter-controller"
  description = "Permissions for Karpenter to provision EKS compute."

  policy = data.aws_iam_policy_document.controller.json

  tags = var.tags
}

resource "aws_iam_role_policy_attachment" "controller" {
  role       = aws_iam_role.controller.name
  policy_arn = aws_iam_policy.controller.arn
}

Phase 14C — Pod Identity

Because we've already standardized this project around EKS Pod Identity, use it here as well:

resource "aws_eks_pod_identity_association" "controller" {
  cluster_name    = var.cluster_name
  namespace       = "karpenter"
  service_account = "karpenter"
  role_arn        = aws_iam_role.controller.arn
}

This gives us:

Karpenter Pod
     │
     ▼
ServiceAccount
     │
     ▼
EKS Pod Identity
     │
     ▼
IAM Role
     │
     ▼
EC2 APIs

Phase 14D — Outputs

Create:

terraform/modules/karpenter/outputs.tf

output "controller_role_arn" {
  description = "IAM role ARN used by the Karpenter controller."
  value       = aws_iam_role.controller.arn
}

Phase 14E — Connect the module

In:

terraform/main.tf

add:

module "karpenter" {
  source = "./modules/karpenter"

  cluster_name = module.eks.cluster_name

  node_role_arn = module.iam.node_role_arn

  tags = {
    Environment = var.environment
  }
}

And in:

terraform/outputs.tf

add:

output "karpenter_controller_role_arn" {
  description = "Karpenter controller IAM role ARN."
  value       = module.karpenter.controller_role_arn
}

Phase 14F — Important: don't install Karpenter yet

We're deliberately stopping here.

Karpenter requires several AWS/Kubernetes integration pieces:

Karpenter
   │
   ├── Controller
   ├── IAM
   ├── NodeClass
   ├── NodePool
   └── EC2 capacity

We should build these in the correct order rather than dumping everything into one Terraform file.

The next part will create:

EC2NodeClass

This defines how Karpenter should provision EC2 instances:

AMI
IAM role
subnets
security groups
instance discovery

Then:

NodePool

This defines what kind of capacity Karpenter is allowed to provision:

instance families
architecture
capacity type
availability zones
resource limits
Phase 14 checkpoint

At this point we're building:

                  EKS
                   │
          ┌────────┴────────┐
          │                 │
       HPA              Karpenter
          │                 │
      Pod scaling       Node scaling
          │                 │
          ▼                 ▼
       Pods             EC2 Nodes

This distinction is fundamental to Kubernetes operations.

Run:

terraform -chdir=terraform fmt -recursive

then:

terraform -chdir=terraform init

then:

terraform -chdir=terraform validate

Do not run terraform apply.

Phase 14G — Install Karpenter

We'll do this in three parts:

Install the Karpenter Helm chart
Create EC2NodeClass
Create NodePool

14G.1 — Add Karpenter Helm installation

You already have:

terraform/helm.tf

Add the following resource there:

resource "helm_release" "karpenter" {
  name             = "karpenter"
  namespace        = "karpenter"
  create_namespace = true

  repository = "oci://public.ecr.aws/karpenter"
  chart      = "karpenter"
  version    = "1.12.1"

  set = [
    {
      name  = "settings.clusterName"
      value = module.eks.cluster_name
    },
    {
      name  = "settings.interruptionQueue"
      value = "${module.eks.cluster_name}-karpenter"
    },
    {
      name  = "serviceAccount.name"
      value = "karpenter"
    }
  ]

  depends_on = [
    module.eks,
    module.karpenter
  ]
}

The current Karpenter documentation shows Helm as the installation mechanism and the current release series uses the v1 API.

Important

We are pinning:

version = "1.12.1"

instead of using:

version = ">= 1.0"

Pinning the version makes your portfolio reproducible.

14G.2 — Create the EC2NodeClass

Create:

terraform/modules/karpenter/nodeclass.tf

Use:

resource "kubernetes_manifest" "ec2_node_class" {
  manifest = {
    apiVersion = "karpenter.k8s.aws/v1"

    kind = "EC2NodeClass"

    metadata = {
      name = "default"
    }

    spec = {
      amiSelectorTerms = [
        {
          alias = "al2023@latest"
        }
      ]

      role = var.node_role_arn

      subnetSelectorTerms = [
        {
          tags = {
            "karpenter.sh/discovery" = var.cluster_name
          }
        }
      ]

      securityGroupSelectorTerms = [
        {
          tags = {
            "karpenter.sh/discovery" = var.cluster_name
          }
        }
      ]

      tags = merge(
        var.tags,
        {
          "karpenter.sh/discovery" = var.cluster_name
        }
      )
    }
  }

}

However, stop before validating this file.

There is an important dependency we need to address first.

Your current VPC/subnet/security-group resources must have the discovery tag:

karpenter.sh/discovery = eks-platform-dev

Karpenter uses subnet and security-group selector terms to discover where it can launch nodes.

So let's inspect your existing EKS networking before we add the NodePool.

Run:

grep -R -n 'karpenter.sh/discovery' terraform/

If nothing is returned, that's expected at this stage.

Then run:

grep -R -n 'aws_subnet\|aws_security_group' terraform/modules/

Don't add the NodePool yet.

We want to make sure the existing AWS networking has the correct discovery tags first.

Why we're doing this

The final architecture will be:

                    EKS
                     │
          ┌──────────┴──────────┐
          │                     │
         HPA                Karpenter
          │                     │
       Pod scaling          Node scaling
                                │
                                ▼
                           NodePool
                                │
                                ▼
                         EC2NodeClass
                                │
                 ┌──────────────┼──────────────┐
                 ▼              ▼              ▼
              Subnets      Security Groups   IAM Role
                 │
                 ▼
              EC2 Nodes

NodePool defines what capacity Karpenter may provision, while EC2NodeClass defines AWS-specific details about how that capacity is created.


1. Add the discovery tag to private subnets

In:

terraform/modules/networking/main.tf

change the private subnet tags from:

tags = merge(
  var.tags,
  {
    Name                              = "${var.name}-private-${each.key}"
    Tier                              = "private"
    "kubernetes.io/role/internal-elb" = "1"
  }
)

to:

tags = merge(
  var.tags,
  {
    Name                              = "${var.name}-private-${each.key}"
    Tier                              = "private"
    "kubernetes.io/role/internal-elb" = "1"
    "karpenter.sh/discovery"          = var.name
  }
)

Because your var.name is:

eks-platform-dev

the resulting tag will be:

karpenter.sh/discovery = eks-platform-dev

which matches:

var.cluster_name

in your EC2NodeClass.


Fix terraform/kubernetes.tf

Change:

data "aws_eks_cluster" "this" {
  name = module.eks.cluster_name
}

data "aws_eks_cluster_auth" "this" {
  name = module.eks.cluster_name
}

provider "kubernetes" {
  host = data.aws_eks_cluster.this.endpoint

  cluster_ca_certificate = base64decode(
    data.aws_eks_cluster.this.certificate_authority[0].data
  )

  token = data.aws_eks_cluster_auth.this.token
}

to:

provider "kubernetes" {
  host = module.eks.cluster_endpoint

  cluster_ca_certificate = base64decode(
    module.eks.cluster_certificate_authority_data
  )

  exec {
    api_version = "client.authentication.k8s.io/v1beta1"

    command = "aws"

    args = [
      "eks",
      "get-token",
      "--cluster-name",
      module.eks.cluster_name,
      "--region",
      var.aws_region
    ]
  }
}

This removes the failing:

data.aws_eks_cluster.this
data.aws_eks_cluster_auth.this

lookup.

Do the same in terraform/helm.tf

Your current:

data "aws_eks_cluster" "helm" {
  name = module.eks.cluster_name
}

data "aws_eks_cluster_auth" "helm" {
  name = module.eks.cluster_name
}

etc

should not be there for this architecture.

Use:


provider "helm" {
  kubernetes = {
    host = module.eks.cluster_endpoint

    cluster_ca_certificate = base64decode(
      module.eks.cluster_certificate_authority_data
    )

    exec = {
      api_version = "client.authentication.k8s.io/v1beta1"

      command = "aws"

      args = [
        "eks",
        "get-token",
        "--cluster-name",
        module.eks.cluster_name,
        "--region",
        var.aws_region
      ]
    }
  }
}

resource "helm_release" "karpenter" {
  name             = "karpenter"
  namespace        = "karpenter"
  create_namespace = true

  repository = "oci://public.ecr.aws/karpenter"
  chart      = "karpenter"
  version    = "1.12.1"

  set = [
    {
      name  = "settings.clusterName"
      value = module.eks.cluster_name
    },
    {
      name  = "settings.interruptionQueue"
      value = "${module.eks.cluster_name}-karpenter"
    },
    {
      name  = "serviceAccount.name"
      value = "karpenter"
    }
  ]

  depends_on = [
    module.eks,
    module.karpenter
  ]
}

This is much closer to what you want: Terraform can establish the dependency on module.eks from the module outputs instead of trying to query an already-existing cluster during planning.

Add terraform/modules/networking/main.tf

resource "aws_security_group" "eks_nodes" {
  name        = "${var.name}-eks-nodes"
  description = "Security group for EKS worker nodes."
  vpc_id      = aws_vpc.this.id

  tags = merge(
    var.tags,
    {
      Name                         = "${var.name}-eks-nodes"
      "karpenter.sh/discovery"     = var.name
    }
  )
}

Add this to terraform/modules/networking/outputs.tf

output "eks_nodes_security_group_id" {
  description = "Security group ID for EKS worker nodes and Karpenter."
  value       = aws_security_group.eks_nodes.id
}

Let's establish that EKS + Karpenter Helm + IAM + baseline node group are healthy first. Then we'll add the EC2NodeClass with the dependency expressed from the root module correctly.

mkdir -p /tmp/terraform-k8s-backup
mv terraform/modules/karpenter/nodeclass.tf /tmp/terraform-k8s-backup/
terraform -chdir=terraform plan -out=/tmp/phase14-bootstrap.tfplan
terraform -chdir=terraform apply "/tmp/phase14-bootstrap.tfplan"