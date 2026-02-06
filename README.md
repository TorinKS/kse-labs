# KSE CI/CD Security Labs

Lab materials for the CI/CD Security course at Kyiv School of Economics. This repository provides hands-on exercises for learning secure CI/CD practices, GitOps, and Kubernetes policy enforcement.

## Repository Structure

```
kse-labs/
├── ci-cd-security/          # CI/CD security examples and configuration
│   ├── configuration/       # Self-hosted runner setup guides
│   └── example-service/     # Sample Go microservice with K8s manifests
├── argocd-configuration/    # ArgoCD GitOps setup guide
├── opa-gatekeeper-configuration/  # OPA Gatekeeper policy configuration
├── prepare-local-k8s/       # Terraform scripts for local K8s cluster
└── .github/workflows/       # GitHub Actions CI pipelines
```

## What You Will Learn

- **Secure CI/CD Pipelines**: Using reusable workflows and trusted workflow enforcement
- **Self-hosted Runners**: Setting up and securing GitHub Actions runners
- **GitOps with ArgoCD**: Declarative continuous delivery for Kubernetes
- **Policy Enforcement**: Using OPA Gatekeeper for Kubernetes admission control
- **Local Kubernetes**: Setting up a production-like K8s cluster for development

## Getting Started

### Prerequisites

- Git
- [Terraform](https://developer.hashicorp.com/terraform/install)
- [Multipass](https://multipass.run/install) (for local K8s cluster)
- kubectl

### 1. Set Up Local Kubernetes Cluster

The `prepare-local-k8s/` directory contains Terraform configurations to provision a local Kubernetes cluster using Multipass VMs.

```bash
cd prepare-local-k8s/scripts/windows  # or /macos for macOS
terraform init
terraform apply
```

This creates a cluster with:
- 1 master node + 2 worker nodes
- HAProxy load balancer
- Pre-installed: ArgoCD, Harbor, Grafana, Prometheus, NFS storage

See [prepare-local-k8s/readme.md](prepare-local-k8s/readme.md) for detailed instructions.

### 2. Configure ArgoCD

Follow the guide in [argocd-configuration/argocd-configuration.md](argocd-configuration/argocd-configuration.md) to:
- Access the ArgoCD web UI
- Connect your Git repository
- Create and manage applications

### 3. Set Up OPA Gatekeeper

Follow [opa-gatekeeper-configuration/opa-gatekeeper-configuration.md](opa-gatekeeper-configuration/opa-gatekeeper-configuration.md) to deploy policy enforcement.

### 4. CI/CD Security Configuration

The `ci-cd-security/` directory contains:
- **Self-hosted runner setup**: [configuration/configuration.md](ci-cd-security/configuration/configuration.md)
- **Example Go service**: A sample microservice demonstrating secure CI/CD practices

## Architecture

```
┌─────────────────┐     ┌──────────────────┐     ┌─────────────────┐
│  GitHub Repo    │────▶│  GitHub Actions  │────▶│  Container      │
│  (Source Code)  │     │  (Trusted        │     │  Registry       │
│                 │     │   Workflows)     │     │  (Harbor)       │
└─────────────────┘     └──────────────────┘     └────────┬────────┘
                                                          │
┌─────────────────┐     ┌──────────────────┐              │
│  Deployment     │◀────│     ArgoCD       │◀─────────────┘
│  Repo           │     │  (GitOps)        │
│  (K8s Manifests)│     │                  │
└─────────────────┘     └──────────────────┘
                               │
                               ▼
                        ┌──────────────────┐
                        │  Kubernetes      │
                        │  Cluster         │
                        │  (OPA Gatekeeper │
                        │   Policy)        │
                        └──────────────────┘
```

## Related Repositories

- [kse-labs-trusted-workflows](https://github.com/TorinKS/kse-labs-trusted-workflows) - Reusable GitHub Actions workflows
- [kse-labs-deployment](https://github.com/TorinKS/kse-labs-deployment) - Kubernetes deployment manifests

## Cost Benefits

Running this local setup vs AWS:
- **Local**: ~$0/month (excluding electricity)
- **AWS Equivalent**: ~$200/month (EKS + EC2 + ALB + storage)

Perfect for learning without cloud costs.

## License

Educational materials for KSE CI/CD Security course.
