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

Phase 14G.3 — Add Karpenter interruption handling

Create:

terraform/modules/karpenter/interruption.tf

Put this in it:

resource "aws_sqs_queue" "interruption" {
  name = "${var.cluster_name}-karpenter"

  message_retention_seconds = 300

  tags = merge(
    var.tags,
    {
      Name = "${var.cluster_name}-karpenter"
    }
  )
}

resource "aws_cloudwatch_event_rule" "spot_interruption" {
  name        = "${var.cluster_name}-karpenter-spot-interruption"
  description = "Karpenter Spot interruption events"

  event_pattern = jsonencode({
    source = [
      "aws.ec2"
    ]

    detail-type = [
      "EC2 Spot Instance Interruption Warning"
    ]
  })

  tags = var.tags
}

resource "aws_cloudwatch_event_target" "spot_interruption" {
  rule = aws_cloudwatch_event_rule.spot_interruption.name
  arn  = aws_sqs_queue.interruption.arn
}

resource "aws_cloudwatch_event_rule" "rebalance" {
  name        = "${var.cluster_name}-karpenter-rebalance"
  description = "Karpenter EC2 rebalance recommendations"

  event_pattern = jsonencode({
    source = [
      "aws.ec2"
    ]

    detail-type = [
      "EC2 Instance Rebalance Recommendation"
    ]
  })

  tags = var.tags
}

resource "aws_cloudwatch_event_target" "rebalance" {
  rule = aws_cloudwatch_event_rule.rebalance.name
  arn  = aws_sqs_queue.interruption.arn
}

resource "aws_cloudwatch_event_rule" "instance_state_change" {
  name        = "${var.cluster_name}-karpenter-instance-state-change"
  description = "Karpenter EC2 instance state changes"

  event_pattern = jsonencode({
    source = [
      "aws.ec2"
    ]

    detail-type = [
      "EC2 Instance State-change Notification"
    ]

    detail = {
      state = [
        "stopping",
        "stopped",
        "shutting-down",
        "terminated"
      ]
    }
  })

  tags = var.tags
}

resource "aws_cloudwatch_event_target" "instance_state_change" {
  rule = aws_cloudwatch_event_rule.instance_state_change.name
  arn  = aws_sqs_queue.interruption.arn
}

resource "aws_sqs_queue_policy" "interruption" {
  queue_url = aws_sqs_queue.interruption.id

  policy = jsonencode({
    Version = "2012-10-17"

    Statement = [
      {
        Sid    = "AllowEventBridgeToSendMessages"
        Effect = "Allow"

        Principal = {
          Service = "events.amazonaws.com"
        }

        Action = "sqs:SendMessage"

        Resource = aws_sqs_queue.interruption.arn

        Condition = {
          ArnEquals = {
            "aws:SourceArn" = [
              aws_cloudwatch_event_rule.spot_interruption.arn,
              aws_cloudwatch_event_rule.rebalance.arn,
              aws_cloudwatch_event_rule.instance_state_change.arn
            ]
          }
        }
      }
    ]
  })
}

One important detail

Your helm.tf currently has:

settings.interruptionQueue

pointing to:

"${module.eks.cluster_name}-karpenter"

Our queue is named:

"${var.cluster_name}-karpenter"

and your root module passes:

cluster_name = module.eks.cluster_name

so both resolve to:

eks-platform-dev-karpenter

Therefore they match.

14G.4 — Add the queue dependency

Now open your root Karpenter module in:

terraform/main.tf

Make sure the Karpenter module looks approximately like:

module "karpenter" {
  source = "./modules/karpenter"

  cluster_name  = module.eks.cluster_name
  node_role_arn = module.iam.node_role_arn

  tags = {
    Environment = var.environment
  }
}

Your existing configuration should already be close to this.

Then make the Helm release explicitly depend on the Karpenter module:

depends_on = [
  module.eks,
  module.karpenter
]

You already have this dependency from the configuration we established, so don't add a duplicate block if it's already there.

14G.5 — Format and validate

Run:

terraform -chdir=terraform fmt -recursive

Then:

terraform -chdir=terraform init

Then:

terraform -chdir=terraform validate

Expected:

Success! The configuration is valid.

Phase 14G.6 — Karpenter networking discovery

Before we create the NodePool, we need to make sure Karpenter can actually discover the AWS resources it is supposed to use.

Your EC2NodeClass currently selects resources using:

"karpenter.sh/discovery" = var.cluster_name

for both subnets and security groups.

We already inspected your networking module earlier, and your private subnets currently have Kubernetes internal-load-balancer tags. We need to add the Karpenter discovery tag to those private subnets.

Edit

Open:

terraform/modules/networking/main.tf

Find:

resource "aws_subnet" "private" {

and its existing tags:

tags = merge(
  var.tags,
  {
    Name                              = "${var.name}-private-${each.key}"
    Tier                              = "private"
    "kubernetes.io/role/internal-elb" = "1"
  }
)

Change it to:

tags = merge(
  var.tags,
  {
    Name                              = "${var.name}-private-${each.key}"
    Tier                              = "private"
    "kubernetes.io/role/internal-elb" = "1"
    "karpenter.sh/discovery"          = var.name
  }
)

Don't change the public subnets. Karpenter should provision worker nodes into the private subnets in this project.

Then run
terraform -chdir=terraform fmt -recursive
terraform -chdir=terraform init
terraform -chdir=terraform validate

Phase 14G.7 — Create the EKS node security group

I recommend creating a dedicated security group in the networking module, because the security group belongs to the VPC/network layer.

Create:

terraform/modules/networking/security-groups.tf

Put this in it:

resource "aws_security_group" "eks_nodes" {
  name        = "${var.name}-eks-nodes"
  description = "Security group for EKS worker nodes"
  vpc_id      = aws_vpc.this.id

  tags = merge(
    var.tags,
    {
      Name                     = "${var.name}-eks-nodes"
      "karpenter.sh/discovery" = var.name
    }
  )
}

Why this particular tag matters

Your Karpenter EC2NodeClass already searches for:

"karpenter.sh/discovery" = var.cluster_name

Your networking module receives the same project/cluster name through var.name.

Therefore:

Networking var.name
        │
        ▼
eks-platform-dev
        │
        ├── private subnet discovery tag
        │
        └── node security-group discovery tag

Karpenter can then discover both.

Add an output

Open:

terraform/modules/networking/outputs.tf

Add:

output "eks_node_security_group_id" {
  description = "Security group ID for EKS worker nodes."
  value       = aws_security_group.eks_nodes.id
}

Pass it through to the EKS module

Now we need to make the security group available to the EKS cluster.

Open:

terraform/modules/eks/variables.tf

Add:

variable "node_security_group_id" {
  description = "Security group ID for EKS worker nodes."
  type        = string
}

Then change:

terraform/modules/eks/main.tf

from:

vpc_config {
  subnet_ids = var.subnet_ids
}

to:

vpc_config {
  subnet_ids = var.subnet_ids

  security_group_ids = [
    var.node_security_group_id
  ]
}

Pass the value from root

Open:

terraform/main.tf

Find your:

module "eks" {

Add:

node_security_group_id = module.networking.eks_node_security_group_id

So conceptually:

module "eks" {
  source = "./modules/eks"

  name               = var.cluster_name
  cluster_role_arn   = module.iam.eks_role_arn
  subnet_ids         = module.networking.private_subnet_ids
  node_security_group_id = module.networking.eks_node_security_group_id

  # existing arguments...
}

Keep your existing variable names exactly as they are. The snippet above is illustrative because I don't want you to accidentally rename an existing input.

One more important change

Your private subnet discovery tag from the previous step should be:

"karpenter.sh/discovery" = var.name

So we now have:

Private subnet
└── karpenter.sh/discovery = eks-platform-dev

EKS node security group
└── karpenter.sh/discovery = eks-platform-dev

And your Karpenter module receives:

cluster_name = eks-platform-dev

Therefore the selectors match.

Then validate

Run:

terraform -chdir=terraform fmt -recursive

then:

terraform -chdir=terraform init

then:

terraform -chdir=terraform validate

Fix kubernetes.tf

Replace the contents of:

terraform/kubernetes.tf

with:

provider "kubernetes" {
  host = module.eks.cluster_endpoint

  cluster_ca_certificate = base64decode(
    module.eks.cluster_certificate_authority_data
  )

  token = data.aws_eks_cluster_auth.this.token
}

data "aws_eks_cluster_auth" "this" {
  name = module.eks.cluster_name

  depends_on = [
    module.eks
  ]
}

Important

We're still using:

data "aws_eks_cluster_auth"

because we need an authentication token.

But we're no longer using data.aws_eks_cluster to discover the endpoint and CA.

Those come directly from the Terraform-managed EKS resource.

Fix helm.tf

Change the top of:

terraform/helm.tf

from:

data "aws_eks_cluster" "helm" {
  name = module.eks.cluster_name
}

data "aws_eks_cluster_auth" "helm" {
  name = module.eks.cluster_name
}

provider "helm" {
  kubernetes = {
    host = data.aws_eks_cluster.helm.endpoint
    cluster_ca_certificate = base64decode(
      data.aws_eks_cluster.helm.certificate_authority[0].data
    )

    token = data.aws_eks_cluster_auth.helm.token
  }
}

to:

data "aws_eks_cluster_auth" "helm" {
  name = module.eks.cluster_name

  depends_on = [
    module.eks
  ]
}

provider "helm" {
  kubernetes = {
    host = module.eks.cluster_endpoint

    cluster_ca_certificate = base64decode(
      module.eks.cluster_certificate_authority_data
    )

    token = data.aws_eks_cluster_auth.helm.token
  }
}

Keep your existing:

resource "helm_release" "karpenter" {

below it unchanged.


First Deploy these

terraform -chdir=terraform apply -target=module.networking -target=module.iam -target=module.eks -target=module.node_group


Next: verify Kubernetes connectivity

Run:

aws eks update-kubeconfig \
  --region ap-southeast-1 \
  --name eks-platform-dev

Then:

kubectl get nodes

Then:

kubectl get nodes -o wide

And finally:

kubectl get pods -A
Expected

kubectl get nodes should show 2 Ready nodes, because we configured:

desired_size = 2
min_size     = 2
max_size     = 3

Something like:

NAME                                           STATUS   ROLES    AGE   VERSION
ip-10-20-x-x.ap-southeast-1.compute.internal Ready    <none>   ...   v1.33.x
ip-10-20-x-x.ap-southeast-1.compute.internal Ready    <none>   ...   v1.33.x

kubectl get pods -A should show the EKS/system components running.

terraform -chdir=terraform plan

Remove the entire helm_release "external_secrets" block from:

terraform/external-secrets.tf

So terraform/external-secrets.tf should either be empty or be removed entirely.

Your helm.tf should retain both releases:

resource "helm_release" "karpenter" {
  ...
}

resource "helm_release" "external_secrets" {
  name             = "external-secrets"
  namespace        = "external-secrets"
  create_namespace = true

  repository = "https://charts.external-secrets.io"
  chart      = "external-secrets"
  version    = "0.20.2"

  set = [
    {
      name  = "installCRDs"
      value = "true"
    },
    {
      name  = "serviceAccount.name"
      value = "external-secrets"
    }
  ]

  depends_on = [
    module.eks,
    module.external_secrets
  ]
}

Then run:

terraform -chdir=terraform fmt -recursive
terraform -chdir=terraform init
terraform -chdir=terraform validate

You should get:

Success! The configuration is valid.

Install External Secrets Operator

Run:

terraform -chdir=terraform apply \
  -target=helm_release.external_secrets

Approve with:

yes

After it finishes, verify:

kubectl get pods -n external-secrets

Then:

kubectl get crd | grep external-secrets.io

We want to see CRDs including something like:

clustersecretstores.external-secrets.io
externalsecrets.external-secrets.io


We need to remove the dependency from the Helm release to the entire module.karpenter.

In terraform/helm.tf, update with this:

data "aws_eks_cluster_auth" "helm" {
  name = module.eks.cluster_name

  depends_on = [
    module.eks
  ]
}

provider "helm" {
  kubernetes = {
    host = module.eks.cluster_endpoint

    cluster_ca_certificate = base64decode(
      module.eks.cluster_certificate_authority_data
    )

    token = data.aws_eks_cluster_auth.helm.token
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
    },
    {
      name  = "settings.aws.region"
      value = var.aws_region
    }
  ]

  depends_on = [
    module.eks
  ]
}

resource "helm_release" "external_secrets" {
  name             = "external-secrets"
  namespace        = "external-secrets"
  create_namespace = true

  repository = "https://charts.external-secrets.io"
  chart      = "external-secrets"
  version    = "0.20.2"

  set = [
    {
      name  = "installCRDs"
      value = "true"
    },
    {
      name  = "serviceAccount.name"
      value = "external-secrets"
    }
  ]

  depends_on = [
    module.eks,
    module.external_secrets
  ]
}

Run:

kubectl delete namespace karpenter

Then wait:

kubectl get namespace karpenter

You want:

Error from server (NotFound)

Do not delete the Karpenter CRDs.

Verify:

kubectl get crd | grep karpenter

You should still see:

ec2nodeclasses.karpenter.k8s.aws
nodeclaims.karpenter.sh
nodeoverlays.karpenter.sh
nodepools.karpenter.sh

That is fine.

Install Karpenter


terraform -chdir=terraform apply -target=module.karpenter

Approve with:

yes

Then check:

kubectl get pods -n karpenter

And:

kubectl get crd ec2nodeclasses.karpenter.k8s.aws

We specifically need:

ec2nodeclasses.karpenter.k8s.aws