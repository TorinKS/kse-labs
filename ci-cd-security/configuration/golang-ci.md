# Go CI/CD Architecture

## Overview

When deploying to a local Kubernetes cluster or testing against local infrastructure, GitHub-hosted runners cannot access private networks (localhost, internal IPs, VPNs). Options to solve this include:

| Approach | Pros | Cons |
|----------|------|------|
| **ngrok/tunneling** | Quick setup | Free tier limits, security concerns, latency |
| **Self-hosted runner per repo** | Full control | Separate setup for each project |
| **Organization-level runner** | Shared across repos | Requires creating an organization |

For this project, we use **self-hosted runner** for CI (build/test) since they require local network access: deployment to local cluster

### Self-Hosted Runner Options

1. **Per-repository**: Register runner to single repo (simplest, but not shared)
2. **Organization-level**: Create a [free GitHub organization](https://github.com/organizations/plan) to share one runner across multiple repos (overhead)


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
└──────────────────────┬──────────────────────────────────────────────┘
                       │ calls reusable workflows
                       ▼
┌─────────────────────────────────────────────────────────────────────┐
│              kse-labs-trusted-workflows (Central Workflows)          │
├─────────────────────────────────────────────────────────────────────┤
│  .github/workflows/                                                  │
│  ├── go-ci.yaml      ──────► Build & test Go applications           │
│  ├── go-release.yaml ──────► Build & upload release binaries        │
│  ├── ci.yaml         ──────► Lint workflows (actionlint, zizmor)    │
│  └── scorecard.yaml  ──────► OpenSSF security scorecard             │
└─────────────────────────────────────────────────────────────────────┘
```

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

**What it does**:
- Checks out code
- Sets up Go environment
- Runs `go build -v ./...`
- Runs `go test -v ./...`

### 2. Release Workflow (`release.yaml`)

**Trigger**: Manual dispatch with version selection

**Purpose**: Create versioned releases with binaries

**Inputs**:
| Input | Description | Options |
|-------|-------------|---------|
| `service` | Service to release | example-service |
| `version_type` | Semver increment | patch, minor, major |

**Release Process**:

```
┌─────────────────┐     ┌─────────────────┐     ┌─────────────────┐
│  1. Get Latest  │────►│  2. Increment   │────►│  3. Create Tag  │
│      Tag        │     │     Version     │     │    & Release    │
└─────────────────┘     └─────────────────┘     └────────┬────────┘
                                                         │
┌─────────────────┐     ┌─────────────────┐              │
│  5. Summary     │◄────│  4. Build &     │◄─────────────┘
│                 │     │     Upload      │
└─────────────────┘     └─────────────────┘
```

**Version Increment Examples**:
- Current: `v1.0.0` + `patch` → `v1.0.1`
- Current: `v1.0.0` + `minor` → `v1.1.0`
- Current: `v1.0.0` + `major` → `v2.0.0`

### 3. Trusted Workflow: `go-ci.yaml`

**Type**: Reusable workflow (`workflow_call`)

**Inputs**:
| Input | Required | Default | Description |
|-------|----------|---------|-------------|
| `go-version` | No | `1.21` | Go version |
| `working-directory` | Yes | - | Path to Go code |

**Steps**:
1. Checkout code
2. Setup Go with caching
3. Build all packages
4. Run all tests

### 4. Trusted Workflow: `go-release.yaml`

**Type**: Reusable workflow (`workflow_call`)

**Inputs**:
| Input | Required | Default | Description |
|-------|----------|---------|-------------|
| `go-version` | No | `1.21` | Go version |
| `working-directory` | Yes | - | Path to Go code |
| `binary-name` | No | `app` | Output binary name |
| `goos` | No | `linux` | Target OS |
| `goarch` | No | `amd64` | Target architecture |
| `ref` | No | - | Git ref to checkout |
| `release-tag` | Yes | - | Tag for release upload |

**Uses**: `wangyoucao577/go-release-action@v1` for cross-compilation and asset upload

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
  contents: write  # Only for release creation
```

### 4. Pin Action Versions

All actions use specific versions (not `@latest`):
```yaml
uses: actions/checkout@v4
uses: actions/setup-go@v5
uses: wangyoucao577/go-release-action@v1
```

## Cross-Compilation

Go supports native cross-compilation. The release workflow can build for any platform:

| GOOS | GOARCH | Output |
|------|--------|--------|
| linux | amd64 | Linux x86_64 |
| linux | arm64 | Linux ARM64 |
| darwin | amd64 | macOS Intel |
| darwin | arm64 | macOS Apple Silicon |
| windows | amd64 | Windows x86_64 |

**Note**: CGO is disabled for cross-compilation. Pure Go code only.

## Usage

### Run CI Manually

```bash
gh workflow run build.yaml --repo TorinKS/kse-labs
```

### Create a Release

```bash
# Via GitHub UI:
# Actions → Release → Run workflow → Select service & version type

# Or via CLI:
gh workflow run release.yaml \
  --repo TorinKS/kse-labs \
  -f service=example-service \
  -f version_type=patch
```

### View Releases

```bash
gh release list --repo TorinKS/kse-labs
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
        └── go.sum

kse-labs-trusted-workflows/
└── .github/workflows/
    ├── go-ci.yaml              # Reusable CI workflow
    ├── go-release.yaml         # Reusable release workflow
    ├── ci.yaml                 # Workflow linting
    └── scorecard.yaml          # Security scanning
```

## Best Practices Implemented

1. **Separation of Concerns**: Trusted workflows in dedicated repo
2. **Semantic Versioning**: Automated version increment
3. **Manual Release Control**: Developers decide when to release
4. **Immutable Artifacts**: SHA256 checksums for binaries
5. **Minimal Build Context**: Only necessary files included
6. **Reproducible Builds**: Pinned Go and action versions
