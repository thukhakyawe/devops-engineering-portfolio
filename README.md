# DevOps & Cloud Engineering Portfolio Roadmap

This repository contains a long-term sequence of practical DevOps,
Cloud, Kubernetes, Infrastructure-as-Code, CI/CD, observability,
security, and platform-engineering projects.

The goal is to build **10+ substantial projects**, with each project
building on skills demonstrated in earlier projects.

## Project Sequence

### Project 1 --- Terraform AWS Platform

**Focus:** Infrastructure as Code and AWS foundations.

-   Terraform modules, variables, outputs, state
-   AWS VPC
-   Public/private subnets
-   Internet Gateway and NAT Gateway
-   Route tables
-   Security Groups
-   IAM
-   Availability Zones
-   Infrastructure lifecycle and destruction

**Goal:** Establish a reusable Terraform/AWS foundation.

------------------------------------------------------------------------

### Project 2 --- AWS EKS + Kubernetes Platform

**Status: IN PROGRESS**

**Focus:** Production-style Kubernetes infrastructure on AWS.

-   AWS VPC
-   EKS
-   Managed node groups
-   IAM
-   EKS Pod Identity
-   Kubernetes namespaces
-   Deployments and Services
-   Ingress
-   AWS Load Balancer Controller
-   External Secrets
-   HPA
-   Karpenter
-   EC2NodeClass
-   NodePool
-   Kubernetes scheduling and node autoscaling


------------------------------------------------------------------------

### Project 3 --- Kubernetes CI/CD + Docker + Amazon ECR

**Focus:** Automated application delivery.

``` text
Git → CI → Test → Docker Build → ECR → Kubernetes
```

Topics:

-   Docker
-   Multi-stage builds
-   Amazon ECR
-   GitHub Actions
-   Automated testing
-   Image tagging/scanning
-   Kubernetes deployment
-   Rollout and rollback

------------------------------------------------------------------------

### Project 4 --- Kubernetes Observability Platform

**Focus:** Monitoring, logging, metrics, and alerting.

Topics:

-   Prometheus
-   Grafana
-   Alertmanager
-   Kubernetes metrics
-   Application metrics
-   Node metrics
-   Logs
-   Dashboards
-   Alerts
-   SLI/SLO concepts
-   Operational troubleshooting

------------------------------------------------------------------------

### Project 5 --- Kubernetes GitOps with Argo CD

**Focus:** GitOps and declarative application delivery.

``` text
Developer → Git → Argo CD → Kubernetes
```

Topics:

-   GitOps principles
-   Argo CD
-   Declarative manifests
-   Synchronization
-   Drift detection
-   Rollback
-   Environment management

------------------------------------------------------------------------

### Project 6 --- Kubernetes Microservices Platform

**Focus:** Distributed application architecture.

Topics:

-   Kubernetes microservices
-   Service discovery
-   ConfigMaps and Secrets
-   Ingress
-   Internal services
-   Scaling
-   Resource requests/limits
-   Health probes
-   Pod disruption budgets
-   Failure scenarios
-   Distributed troubleshooting

------------------------------------------------------------------------

### Project 7 --- AWS Serverless Platform

**Focus:** Event-driven and serverless architecture.

Potential architecture:

``` text
Client
  |
  v
API Gateway
  |
  v
Lambda
  |
  +--> DynamoDB
  +--> S3
  +--> EventBridge / SQS
```

Topics:

-   Lambda
-   API Gateway
-   DynamoDB
-   S3
-   EventBridge
-   SQS
-   IAM
-   CloudWatch
-   Terraform
-   Event-driven architecture

------------------------------------------------------------------------

### Project 8 --- AWS Data Platform

**Focus:** Cloud data infrastructure.

Potential architecture:

``` text
Data Sources
     |
     v
    S3
     |
     v
 Processing
     |
     v
 Data Catalog
     |
     v
 Analytics / Query
```

Topics:

-   Amazon S3
-   Data lake concepts
-   IAM
-   Glue
-   Athena
-   Event-driven ingestion
-   Terraform
-   Data partitioning
-   Security
-   Cost awareness

------------------------------------------------------------------------

### Project 9 --- AWS Multi-Account & Cloud Governance

**Focus:** AWS organization, security, and governance.

Topics:

-   AWS Organizations
-   Multiple accounts
-   IAM
-   Service Control Policies
-   Centralized logging
-   CloudTrail
-   Security controls
-   Resource tagging
-   Cost allocation
-   Environment separation
-   Infrastructure provisioning

------------------------------------------------------------------------

## Projects 10+

The portfolio should continue beyond Project 9.

### Project 10 --- High Availability & Disaster Recovery

-   Multi-AZ architecture
-   Backup and restore
-   Disaster recovery
-   RTO/RPO
-   Failure testing
-   Recovery automation
-   Resilience engineering

### Project 11 --- DevSecOps Platform

Integrate security throughout the software lifecycle:

``` text
Code
 |
 +--> SAST
 +--> Dependency scanning
 +--> Secret scanning
 +--> Container scanning
 +--> IaC scanning
 |
 v
CI/CD
 |
 v
Deployment
```

Potential tools:

-   Trivy
-   Checkov
-   GitHub security features
-   Container image scanning

### Project 12 --- Advanced GitOps Platform

-   Multiple environments
-   Promotion workflows
-   ApplicationSets
-   Progressive delivery
-   Rollbacks
-   Environment-specific configuration
-   Policy enforcement

### Project 13 --- Platform Engineering / Internal Developer Platform

Build reusable infrastructure and deployment abstractions for
application teams.

-   Self-service environments
-   Terraform modules
-   Kubernetes platform abstractions
-   Golden paths
-   Developer experience
-   Platform APIs
-   Standardized observability and security

### Project 14 --- Production Kubernetes Security

-   RBAC
-   NetworkPolicies
-   Pod Security
-   Secrets management
-   Workload identity
-   Admission controls
-   Supply-chain security
-   Runtime security

### Project 15 --- DevOps / Cloud Capstone

Combine the previous skills into one production-style platform:

``` text
                       Git
                        |
                        v
                   CI Pipeline
                        |
             +----------+----------+
             |                     |
             v                     v
          Security             Docker Build
             |                     |
             +----------+----------+
                        |
                        v
                       ECR
                        |
                        v
                     GitOps
                        |
                        v
                       EKS
          +-------------+-------------+
          |             |             |
         HPA       Karpenter      Services
          |             |             |
          +-------------+-------------+
                        |
                        v
                 Observability
                        |
                        v
               Metrics / Logs / Alerts
```

The capstone should demonstrate the complete lifecycle:

``` text
Infrastructure
      ↓
Application
      ↓
CI/CD
      ↓
Security
      ↓
Deployment
      ↓
Scaling
      ↓
Observability
      ↓
Reliability
      ↓
Operations
```

------------------------------------------------------------------------

# Project Rules

## 1. Infrastructure as Code

Prefer Terraform for infrastructure that can reasonably be managed
declaratively.

## 2. Reproducibility

Each project should be reproducible from the repository with documented
prerequisites and commands.

## 3. Security

Use least-privilege IAM and never commit real credentials, API keys,
passwords, private keys, or real Kubernetes secrets.

## 4. Documentation

Every project should document:

-   Architecture
-   Purpose
-   Prerequisites
-   Repository structure
-   Deployment
-   Verification
-   Troubleshooting
-   Destruction/cleanup
-   Lessons learned

## 5. Destroyability

Infrastructure projects should have a documented and tested cleanup
path.

For Terraform:

``` bash
terraform plan -destroy
```

should be used to inspect destructive changes before execution.

## 6. Incremental Development

Build projects through checkpoints:

``` text
Foundation
   ↓
Validation
   ↓
Core infrastructure
   ↓
Application
   ↓
Integration
   ↓
Observability
   ↓
Scaling
   ↓
Testing
```

## 7. Explain Architectural Decisions

Document not only **what** was built, but **why**.

For example, Project 2 deliberately separates:

-   HPA → Pod scaling
-   Karpenter → Node capacity scaling

------------------------------------------------------------------------

# Current Project 2 Git State

Project 2 currently uses:

``` text
phase-14
```

Current Phase 14 commit:

``` text
09ee3fb feat: Update Phase 14 — EKS Node Autoscaling
```

Continue Phase 14 from this branch until the phase is complete.

After completion, merge the work into the project's main development
branch and remove the temporary phase branch when appropriate.

------------------------------------------------------------------------

# Long-Term Goal

The portfolio should demonstrate progression from:

``` text
Terraform
   ↓
AWS
   ↓
Kubernetes
   ↓
CI/CD
   ↓
Observability
   ↓
GitOps
   ↓
Security
   ↓
Serverless
   ↓
Data Platforms
   ↓
Cloud Governance
   ↓
Platform Engineering
   ↓
Production Architecture
```

The overall objective is to demonstrate the ability to **design,
provision, deploy, secure, scale, observe, troubleshoot, and operate
cloud-native systems**.

---

━━━━━━━━━━━━━━━━━━━━━━━━━━━━
LAYER  X
━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Goal

Architecture

Technologies

Terraform code

Why each resource exists

Commands

terraform plan

Review plan

terraform apply

Verification

Troubleshooting

What you learned

Interview questions

Git commit
━━━━━━━━━━━━━━━━━━━━━━━━━━━━