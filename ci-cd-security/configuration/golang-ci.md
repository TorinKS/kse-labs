# Go CI/CD Architecture

## Overview

When deploying to a local Kubernetes cluster or testing against local infrastructure, GitHub-hosted runners cannot access private networks (localhost, internal IPs, VPNs). Options to solve this include:

| Approach | Pros | Cons |
|----------|------|------|
| **ngrok/tunneling** | Quick setup | Free tier limits, security concerns, latency |
| **Self-hosted runner per repo** | Full control | Separate setup for each project |
| **Organization-level runner** | Shared across repos | Requires creating an organization |

For this project, we use **GitHub-hosted runners** for CI (build/test) and **self-hosted runner** for deployment to local cluster.

### Self-Hosted Runner Options

1. **Per-repository**: Register runner to single repo (simplest, but not shared)
2. **Organization-level**: Create a [free GitHub organization](https://github.com/organizations/plan) to share one runner across multiple repos

## Architecture Diagram

```
┌─────────────────────────────────────────────────────────────────────┐
│                         kse-labs (Application Repo)                  │
├─────────────────────────────────────────────────────────────────────┤
│  .github/workflows/                                                  │
│  ├── build.yaml      ──────► CI: build & test on push/PR            │
│  └── release.yaml    ──────► Release: manual version increment       │
│                                                                      │
│  ci-cd-security/                                                     │
│  └── example-service/        Go application source code              │
│       ├── main.go                                                    │
│       ├── Dockerfile                                                 │
│       └── k8s/               Kubernetes manifests                    │
└──────────────────────┬──────────────────────────────────────────────┘
                       │ calls reusable workflows
                       ▼
┌─────────────────────────────────────────────────────────────────────┐
│              kse-labs-trusted-workflows (Central Workflows)          │
├─────────────────────────────────────────────────────────────────────┤
│  .github/workflows/                                                  │
│  ├── go-ci.yaml             ──────► Build & test Go applications    │
│  ├── go-docker-release.yaml ──────► Build binary + Docker image     │
│  ├── ci.yaml                ──────► Lint workflows (actionlint)     │
│  └── scorecard.yaml         ──────► OpenSSF security scorecard      │
└─────────────────────────────────────────────────────────────────────┘
```

## Release Flow (Optimized - Build Once)

```
┌─────────────────┐
│ increment-version│
│  1. Get tag     │
│  2. Bump version│
│  3. Create tag  │
│  4. Create      │
│     GitHub      │
│     Release     │
└────────┬────────┘
         │
         ▼
┌─────────────────────────────────────┐
│       build-and-release             │
│  1. go build → binary               │
│  2. tar + sha256 → GitHub Release   │
│  3. docker build (uses same binary) │
│  4. docker push → ghcr.io           │
└────────┬────────────────────────────┘
         │
         ▼
┌─────────────────┐
│    summary      │
└─────────────────┘
```

**Key optimization**: Binary is built **once** and used for both GitHub Release and Docker image.

## Workflow Details

### 1. CI Workflow (`build.yaml`)

**Trigger**: Push to main, Pull Requests, Manual dispatch

**Purpose**: Validate code quality on every change

```yaml
on:
  push:
    branches: [main]
    paths:
      - 'ci-cd-security/example-service/**'
  pull_request:
    branches: [main]
  workflow_dispatch:

jobs:
  build:
    uses: TorinKS/kse-labs-trusted-workflows/.github/workflows/go-ci.yaml@main
    with:
      go-version: '1.21'
      working-directory: ci-cd-security/example-service
```

### 2. Release Workflow (`release.yaml`)

**Trigger**: Manual dispatch with version selection

**Inputs**:
| Input | Description | Options |
|-------|-------------|---------|
| `service` | Service to release | example-service |
| `version_type` | Semver increment | patch, minor, major |

**Outputs**:
- Binary: `example-service-v1.0.x-linux-amd64.tar.gz` (GitHub Release)
- Docker: `ghcr.io/torinks/example-service:v1.0.x` (Container Registry)

### 3. Trusted Workflow: `go-ci.yaml`

**Type**: Reusable workflow (`workflow_call`)

**Inputs**:
| Input | Required | Default | Description |
|-------|----------|---------|-------------|
| `go-version` | No | `1.21` | Go version |
| `working-directory` | Yes | - | Path to Go code |

### 4. Trusted Workflow: `go-docker-release.yaml`

**Type**: Reusable workflow (`workflow_call`)

**Inputs**:
| Input | Required | Default | Description |
|-------|----------|---------|-------------|
| `go-version` | No | `1.21` | Go version |
| `working-directory` | Yes | - | Path to Go code |
| `binary-name` | Yes | - | Output binary name |
| `image-name` | Yes | - | Docker image name |
| `release-tag` | Yes | - | Version tag |
| `registry` | No | `ghcr.io` | Container registry |

## Commands Reference

### CI Operations

```bash
# Run CI manually
gh workflow run build.yaml --repo TorinKS/kse-labs

# Check workflow status
gh run list --repo TorinKS/kse-labs --limit 5

# View workflow logs
gh run view <RUN_ID> --repo TorinKS/kse-labs --log
```

### Release Operations

```bash
# Create a release (via CLI)
gh workflow run release.yaml \
  --repo TorinKS/kse-labs \
  -f service=example-service \
  -f version_type=patch

# List releases
gh release list --repo TorinKS/kse-labs

# View specific release
gh release view v1.0.5 --repo TorinKS/kse-labs

# List release assets
gh release view v1.0.5 --repo TorinKS/kse-labs --json assets --jq '.assets[].name'

# Download release binary
gh release download v1.0.5 --repo TorinKS/kse-labs --pattern "*.tar.gz"
```

### Docker Operations

```bash
# Login to GitHub Container Registry
echo $GITHUB_TOKEN | docker login ghcr.io -u USERNAME --password-stdin

# Pull image
docker pull ghcr.io/torinks/example-service:v1.0.5
docker pull ghcr.io/torinks/example-service:latest

# List local images
docker images ghcr.io/torinks/example-service

# Run container
docker run -p 8080:8080 ghcr.io/torinks/example-service:v1.0.5

# View image in browser
# https://github.com/TorinKS/kse-labs/pkgs/container/example-service
```

### Git Tag Operations

```bash
# List tags
git tag -l

# Create and push tag manually
git tag -a v1.0.0 -m "Release v1.0.0"
git push origin v1.0.0

# Delete tag (local and remote)
git tag -d v1.0.0
git push origin --delete v1.0.0
```

## Dockerfile (Optimized)

Uses pre-built binary from CI pipeline (no multi-stage build needed):

```dockerfile
FROM alpine:3.19
RUN apk --no-cache add ca-certificates
WORKDIR /app
ARG BINARY_PATH=example-service
COPY ${BINARY_PATH} /app/server
RUN chmod +x /app/server
EXPOSE 8080
USER nobody
ENTRYPOINT ["/app/server"]
```

## Security Features

### 1. Centralized Trusted Workflows

All workflow logic is in a separate repository (`kse-labs-trusted-workflows`), preventing:
- Unauthorized workflow modifications via PR
- Injection of malicious build steps
- Token theft through workflow manipulation

### 2. Workflow Security Scanning

The trusted workflows repo runs:
- **actionlint**: Validates GitHub Actions syntax
- **zizmor**: Detects security issues in workflows
- **OpenSSF Scorecard**: Measures security posture

### 3. Minimal Permissions

```yaml
permissions:
  contents: write   # For release creation
  packages: write   # For Docker push
```

### 4. Pinned Action Versions

```yaml
uses: actions/checkout@v4
uses: actions/setup-go@v5
uses: docker/build-push-action@v5
```

## File Structure

```
kse-labs/
├── .github/workflows/
│   ├── build.yaml              # CI workflow
│   └── release.yaml            # Release workflow
└── ci-cd-security/
    └── example-service/
        ├── main.go
        ├── go.mod
        ├── go.sum
        ├── Dockerfile
        └── k8s/
            ├── deployment.yaml
            └── service.yaml

kse-labs-trusted-workflows/
└── .github/workflows/
    ├── go-ci.yaml              # Reusable CI workflow
    ├── go-docker-release.yaml  # Combined build + Docker workflow
    ├── go-release.yaml         # Binary-only release (legacy)
    ├── docker-build.yaml       # Docker-only build (standalone)
    ├── ci.yaml                 # Workflow linting
    └── scorecard.yaml          # Security scanning
```

## Best Practices Implemented

1. **Separation of Concerns**: Trusted workflows in dedicated repo
2. **Semantic Versioning**: Automated version increment (patch/minor/major)
3. **Manual Release Control**: Developers decide when to release
4. **Build Once**: Binary built once, used for release and Docker
5. **Immutable Artifacts**: SHA256 checksums for binaries
6. **Container Registry**: Images pushed to ghcr.io with version tags
7. **Reproducible Builds**: Pinned Go and action versions
8. **Lowercase Registry**: Automatic lowercase conversion for Docker tags
