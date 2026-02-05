# Migration Guide

This guide explains how to migrate your existing Terraform Kubernetes Multipass configuration to the new multi-platform structure.

## Overview

The project has been reorganized to support multiple platforms:
- Original `multipass/` directory → Now `macos/` directory
- New `windows/` directory for Windows support
- Root `multipass.tf` updated to select platform

## For Existing Users (macOS/Linux)

If you were already using this project, your code is now in the `macos/` directory.

### Option 1: Continue Using Root Directory

Update your `multipass.tf`:

```hcl
module "multipass" {
  source = "./macos"  # Changed from "./multipass"
}
```

Then run:
```bash
terraform init -upgrade
terraform plan  # Should show no changes if infrastructure is unchanged
```

### Option 2: Work Directly in macOS Directory

```bash
# Move into the macOS directory
cd macos

# Initialize and manage infrastructure from there
terraform init
terraform plan
terraform apply
```

## For New Windows Users

1. **Navigate to Windows directory:**
```powershell
cd windows
```

2. **Ensure prerequisites are met:**
   - PowerShell 5.1+
   - SSH keys at `%USERPROFILE%\.ssh\`
   - Multipass installed

3. **Initialize and apply:**
```powershell
terraform init
terraform apply
```

## Migrating Between Platforms

### From macOS to Windows

1. **On macOS - Destroy existing infrastructure:**
```bash
cd macos
terraform destroy
cd ..
./reset-macos.sh
```

2. **On Windows - Create new infrastructure:**
```powershell
cd windows
terraform init
terraform apply
```

### From Windows to macOS

1. **On Windows - Destroy existing infrastructure:**
```powershell
cd windows
terraform destroy
cd ..
.\reset-windows.ps1
```

2. **On macOS - Create new infrastructure:**
```bash
cd macos
terraform init
terraform apply
```

## State Management

### Separate State Files

Each platform directory maintains its own Terraform state:
- `macos/terraform.tfstate`
- `windows/terraform.tfstate`

This means you can have separate deployments per platform, or migrate between them.

### Shared Remote State (Advanced)

If you want to share state across platforms, configure a remote backend:

```hcl
# In macos/versions.tf or windows/versions.tf
terraform {
  backend "s3" {
    bucket = "my-terraform-state"
    key    = "kubernetes-multipass/terraform.tfstate"
    region = "us-west-2"
  }
  
  required_providers {
    # ... existing providers
  }
}
```

## Directory Structure Comparison

### Before:
```
.
├── multipass/
│   ├── script/
│   │   ├── cloud-init.yaml
│   │   ├── cloud-init-haproxy.yaml
│   │   ├── haproxy.cfg.tpl
│   │   ├── kube-init.sh
│   │   └── multipass.py
│   ├── data.tf
│   ├── dns.tf
│   ├── haproxy.tf
│   └── ...
├── multipass.tf
└── reset.sh
```

### After:
```
.
├── macos/                      # macOS/Linux implementation
│   ├── script/
│   │   ├── cloud-init.yaml
│   │   ├── cloud-init-haproxy.yaml
│   │   ├── haproxy.cfg.tpl
│   │   ├── kube-init.sh
│   │   └── multipass.py
│   ├── data.tf
│   ├── dns.tf
│   └── ...
├── windows/                    # Windows implementation
│   ├── script/
│   │   ├── cloud-init.yaml
│   │   ├── cloud-init-haproxy.yaml
│   │   ├── haproxy.cfg.tpl
│   │   ├── kube-init.sh
│   │   └── multipass.ps1      # PowerShell instead of Python
│   ├── data.tf                 # Windows-adapted paths
│   ├── dns.tf                  # Windows-adapted commands
│   └── ...
├── multipass.tf                # Updated to select platform
├── reset-macos.sh              # macOS cleanup
└── reset-windows.ps1           # Windows cleanup
```

## Common Migration Issues

### Issue: Module Not Found
**Error:** `Module not found: module.multipass`

**Solution:** Update `multipass.tf` source path:
```hcl
module "multipass" {
  source = "./macos"  # or "./windows"
}
```

Then run:
```bash
terraform init -upgrade
```

### Issue: State Path Changed
**Error:** Terraform can't find existing state

**Solution:** If you were using the root directory, your state is at `./terraform.tfstate`. Either:
1. Move it to the platform directory: `mv terraform.tfstate macos/`
2. Continue using root directory with updated module source

### Issue: SSH Key Path Errors
**Error:** Cannot find SSH keys

**Solution:** Ensure keys are in the correct location:
- macOS: `~/.ssh/id_rsa`
- Windows: `%USERPROFILE%\.ssh\id_rsa`

Generate if needed:
```bash
# macOS/Linux
ssh-keygen -t rsa -b 4096 -f ~/.ssh/id_rsa

# Windows
ssh-keygen -t rsa -b 4096 -f "$env:USERPROFILE\.ssh\id_rsa"
```

## Backward Compatibility

The `multipass/` directory still exists for backward compatibility. However, it's recommended to use the platform-specific directories:
- Use `macos/` for macOS/Linux
- Use `windows/` for Windows

## Testing Your Migration

After migrating, verify your setup:

```bash
# Check Multipass VMs
multipass list

# Check Terraform state
terraform show

# Verify Kubernetes cluster
export KUBECONFIG=~/.kube/config-multipass  # macOS
# or
$env:KUBECONFIG = "$env:USERPROFILE\.kube\config-multipass"  # Windows

kubectl get nodes
kubectl get pods -A
```

## Rollback

If you encounter issues:

1. **Destroy new infrastructure:**
```bash
terraform destroy
```

2. **Restore from backup:**
```bash
# If you backed up your state file
cp terraform.tfstate.backup terraform.tfstate
```

3. **Reinitialize:**
```bash
terraform init
terraform plan
```

## Getting Help

- Review the [PLATFORM_COMPARISON.md](PLATFORM_COMPARISON.md) for detailed differences
- Check [QUICKSTART.md](QUICKSTART.md) for fresh setup instructions
- Open an issue on GitHub if you encounter problems

## Best Practices

1. **Backup your state file** before migrating
2. **Test in a separate directory** first
3. **Document any customizations** you've made
4. **Use version control** to track changes
5. **Verify infrastructure** before destroying old setup
