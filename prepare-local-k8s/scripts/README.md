# terraform-multipass-kubernetes
Build a Local Kubernetes cluster the easiest way - Now with Multi-Platform Support!

The cluster is built using [Kubeadm](https://kubernetes.io/docs/setup/production-environment/tools/kubeadm/create-cluster-kubeadm/), providing 1 control-plane node and 3 worker nodes, although you can customize this setup.

## Platform Support

This project now supports multiple platforms:

- **macOS**: Use the `macos/` directory (bash/python based)
- **Windows**: Use the `windows/` directory (PowerShell based)

## Platform-Specific Setup

### macOS / Linux

```bash
cd macos
terraform init
terraform apply
```

See [macos/README.md](macos/README.md) for detailed macOS instructions.

### Windows

```powershell
cd windows
terraform init
terraform apply
```

See [windows/README.md](windows/README.md) for detailed Windows instructions.

## Prerequisites

### All Platforms
* [Terraform](https://developer.hashicorp.com/terraform/downloads?product_intent=terraform)
* [Multipass](https://multipass.run/)
* [Kubectl](https://kubernetes.io/docs/tasks/tools/#kubectl)
* SSH key pair generated (`id_rsa` / `id_rsa.pub`)

### macOS / Linux Specific
* Python 3.x
* Bash shell

### Windows Specific
* PowerShell 5.1 or later
* Hyper-V or VirtualBox backend for Multipass
