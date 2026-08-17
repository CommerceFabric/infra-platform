# CommerceFabric Infrastructure — Technical Architecture

This document describes how `infra-platform` provisions, configures and deploys the CommerceFabric platform.

# Prerequisites

Before the automated deployment workflows can run, GitHub must have an identity that is trusted by Azure.

## GitHub → Azure Authentication

GitHub Actions authenticates to Azure using **Microsoft Entra Workload Identity Federation (OIDC)**.

This avoids storing a long-lived Azure client secret in GitHub.

The initial setup requires:

1. A Microsoft Entra application/service principal for GitHub Actions.
2. A **Federated Identity Credential** linking the GitHub repository/workflow to that application.
3. The following GitHub repository secrets:

```text
AZURE_CLIENT_ID
AZURE_TENANT_ID
AZURE_SUBSCRIPTION_ID
```

`AZURE_CLIENT_ID` identifies the GitHub deployment application. No Azure client secret is required because authentication uses OIDC.

## Required Azure Permissions

Because `deploy-all.yml` can recreate an environment from scratch, the GitHub deployment principal requires permissions at the **subscription scope**.

| Role | Purpose |
|---|---|
| **Contributor** | Allows the workflow to create the Resource Group and create/update Azure resources through Bicep. |
| **Role Based Access Control Administrator** | Allows `rbac.bicep` to create the required role assignments between GitHub, AKS and ACR. |

The deployment principal therefore acts as the bootstrap identity:

```text
GitHub Actions
      │
      │ OIDC
      ▼
Microsoft Entra ID
      │
      ▼
GitHub Deployment Service Principal
      │
      ├── Contributor
      │       └── Create/update Azure infrastructure
      │
      └── Role Based Access Control Administrator
              └── Create required RBAC assignments
```

Once AKS and ACR exist, `rbac.bicep` creates the resource-specific permissions required by the platform, including:

```text
AKS kubelet identity
    └── AcrPull → ACR

GitHub deployment identity
    ├── AcrPush → ACR
    └── AKS Cluster User → AKS
```

> The GitHub OIDC application and its subscription-level bootstrap permissions must exist before the first deployment. They intentionally sit outside the Bicep deployment lifecycle so that GitHub retains the ability to recreate a deleted CommerceFabric environment.

# Techincal Notes

## 1. Repository Responsibilities

`infra-platform` owns three layers of the platform:

### Azure infrastructure

Defined using Bicep:

- Azure Kubernetes Service
- Azure Container Registry
- Azure Service Bus
- Azure API Management
- Azure RBAC

### Kubernetes platform

Defined using Kubernetes manifests:

- API Gateway
- Orders microservice
- Products microservice
- Users microservice
- MongoDB
- PostgreSQL
- MySQL
- Redis
- RabbitMQ
- supporting Services and Jobs

### Deployment automation

Implemented using GitHub Actions and PowerShell:

- Azure environment bootstrap/reconciliation
- Kubernetes deployment
- runtime secret configuration
- microservice releases
- APIM API import
- APIM policy deployment

---

# 2. Bicep

## `main.bicep`

`main.bicep` is the entry point for the main Azure environment.

Rather than defining every resource in one file, it coordinates reusable modules:

```text
main.bicep
 ├── modules/aks.bicep
 ├── modules/acr.bicep
 ├── modules/servicebus.bicep
 └── modules/apim.bicep
```

Parameters control environment-specific values such as resource names, locations and SSH configuration.

The same modules can therefore create different environments without duplicating infrastructure definitions.

## Parameter files

```text
main.bicepparam
main.test.bicepparam
```

provide environment-specific configuration.

For example:

```text
Production
commercefabric-aks-cluster
commercefabricregistry
commercefabricapimanagement

Test
commercefabric-aks-test
commercefabricregistrytest
commercefabricapimtest
```

## `rbac.bicep`

RBAC is deployed after the main infrastructure because the AKS kubelet identity is generated when the cluster is created.

It establishes relationships including:

```text
AKS kubelet
   └── AcrPull → ACR

GitHub deployment identity
   ├── AcrPush → ACR
   └── AKS Cluster User → AKS
```

The GitHub deployment identity also has the Azure permissions required for the full environment workflow to create resources and configure RBAC.

---

# 3. Identity Infrastructure

Microsoft Entra External ID is managed separately under:

```text
infra/modules/identity/
```

This includes:

```text
main.identity.bicep
configure-identity.ps1
backend-app.bicep
frontend-app.bicep
```

It manages the application registrations required by the CommerceFabric frontend/backend authentication model.

Identity is separated because the External ID tenant is not part of the normal CommerceFabric resource-group lifecycle.

Deleting and recreating the main Azure environment therefore does not require recreating the External ID tenant.

---

# 4. Kubernetes Architecture

All CommerceFabric workloads run inside:

```text
commercefabric-namespace
```

The public request path is:

```text
Client
  │
  ▼
Azure API Management
  │
  ▼
AKS LoadBalancer
  │
  ▼
API Gateway
  │
  ├── Orders
  ├── Products
  └── Users
```

Internal Kubernetes Services provide DNS-based communication between workloads.

For example:

```text
Orders → mongodb:27017
Products → mysql:3306
Users → postgres:5432
```

Supporting infrastructure uses pinned public container images where no CommerceFabric-specific image is required.

CommerceFabric application images are stored in the environment's private ACR.

---

# 5. Azure Service Bus

Service Bus provides asynchronous communication between services.

The Bicep deployment creates the namespace, topics and subscriptions required by CommerceFabric.

Examples include:

```text
orders.created
   └── orders.created.products

products.updates
   └── products.updates.orders

products.deletes
```

The deployment workflow retrieves the Service Bus connection string from Azure and creates/updates the corresponding Kubernetes Secret.

The connection string therefore does not need to be committed to the repository.

---

# 6. API Management

APIM forms the public API boundary.

Configuration is split between:

```text
configure-apim.ps1
apim/*.swagger.json
modules/apim-policies.bicep
apim/api-policy.xml
```

## OpenAPI definitions

The Swagger/OpenAPI documents describe the routes exposed through APIM for:

- Orders
- Products
- Users

They describe the API contract; they do not contain environment-specific backend IP addresses.

## `configure-apim.ps1`

The script:

1. discovers the API Gateway LoadBalancer address,
2. constructs the gateway backend URL,
3. imports the OpenAPI specifications into APIM,
4. configures the APIM APIs to forward requests to the gateway,
5. deploys the API policy Bicep.

Paths are resolved relative to the script using `$PSScriptRoot`, allowing the script to run both locally on Windows and on GitHub's Linux runners.

## APIM policies

`apim-policies.bicep` applies the policy definition stored in `api-policy.xml`.

Policies provide cross-cutting API behaviour such as JWT validation and CORS.

---

# 7. Full Environment Workflow

`deploy-all.yml` owns environment creation and full reconciliation.

The workflow:

1. authenticates to Azure using GitHub OIDC,
2. resolves the selected production/test environment,
3. creates the resource group when necessary,
4. handles APIM soft-delete recovery,
5. deploys the main Bicep infrastructure,
6. deploys RBAC,
7. connects to AKS,
8. creates the Kubernetes namespace,
9. retrieves runtime Azure configuration,
10. creates/updates Kubernetes Secrets,
11. applies Kubernetes manifests,
12. verifies workloads,
13. configures APIM.

## Bootstrap mode

A newly-created ACR does not initially contain CommerceFabric application images.

`bootstrap: true` therefore allows infrastructure and Kubernetes resources to be created without requiring every application Deployment to become healthy immediately.

The individual application CI pipelines can then populate ACR and trigger their normal deployments.

Once the required images exist, a normal deployment can perform strict rollout and Job validation.

---

# 8. Microservice Deployment Workflow

`deploy-microservice.yml` performs incremental application releases.

It accepts:

```text
environment
service
image_tag
```

The workflow:

1. authenticates using OIDC,
2. resolves the target environment,
3. verifies that the Azure environment exists,
4. resolves the environment's ACR,
5. verifies the requested image/tag exists,
6. connects to AKS,
7. refreshes required Kubernetes Secrets,
8. updates the Deployment image,
9. waits for the Kubernetes rollout,
10. reconciles APIM configuration.

No infrastructure recreation is required for a normal application release.

---

# 9. Microservice CI

Application repositories own their build pipelines.

A typical release is:

```text
git push
   │
   ▼
Unit/integration tests
   │
   ▼
Docker build
   │
   ▼
Version image
   │
   ▼
Push → environment ACR
   │
   ▼
repository_dispatch
   │
   ▼
infra-platform/deploy-microservice.yml
```

This separates:

```text
Application repository
→ build and publish

infra-platform
→ provision and deploy
```

---

# 10. Authentication and Secrets

## GitHub → Azure

GitHub uses Workload Identity Federation (OIDC).

```text
GitHub Actions
   │ OIDC token
   ▼
Microsoft Entra ID
   │
   ▼
Azure deployment identity
```

This avoids storing a long-lived Azure service-principal password in GitHub.

## Runtime secrets

Sensitive runtime values are represented as Kubernetes Secrets.

Examples include:

- Azure Service Bus connection string
- Entra backend application secret

Where possible, generated Azure values are retrieved dynamically during deployment rather than duplicated as permanent GitHub secrets.

---

# 11. Recovery Model

The main Azure environment is intentionally reproducible.

If the resource group is removed:

```text
GitHub Actions
   ↓
main.bicep
   ↓
Azure resources recreated
   ↓
rbac.bicep
   ↓
permissions recreated
   ↓
Kubernetes manifests
   ↓
platform structure recreated
   ↓
application CI pipelines
   ↓
application images deployed
```

APIM soft deletion is handled by the deployment workflow because an APIM service name may remain reserved after resource-group deletion.

Microsoft Entra External ID is outside this lifecycle and is managed separately.

---

# 12. Environment Model

The deployment automation currently supports:

```text
production
test
```

Both environments use the same infrastructure and deployment definitions with different parameter values.

The test environment is intentionally disposable and is used to validate infrastructure changes and disaster-recovery behaviour before production changes are made.