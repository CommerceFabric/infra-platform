# CommerceFabric Infrastructure Platform

`infra-platform` contains the Infrastructure as Code (IaC), Kubernetes configuration, and deployment automation used to run **CommerceFabric** on Microsoft Azure.

It provides a reproducible deployment process for the platform: Azure infrastructure can be created from Bicep, workloads deployed to AKS, and individual microservices released independently through GitHub Actions.

## More Info

- For more info, please see:
  - [Deployment Flow and Diagrams](./docs/DeploymentFlow.md)
  - [Lower Level Technical Documentation](./docs/Technical.md)

## Architecture

CommerceFabric runs primarily on:

| Component | Purpose |
|---|---|
| **Azure Kubernetes Service (AKS)** | Runs the API Gateway, microservices, databases, cache and messaging workloads. |
| **Azure Container Registry (ACR)** | Stores versioned CommerceFabric application images built by the service repositories. |
| **Azure Service Bus** | Provides asynchronous communication between microservices using topics and subscriptions. |
| **Azure API Management (APIM)** | Public API boundary providing routing, JWT validation and CORS policies. |
| **Microsoft Entra External ID** | Provides customer identity and authentication. |
| **GitHub Actions** | Provisions Azure infrastructure and performs application deployments using OIDC authentication. |

Application workloads run inside the `commercefabric-namespace` Kubernetes namespace.

Third-party workloads such as MongoDB, PostgreSQL, MySQL, Redis and RabbitMQ use pinned upstream container images. CommerceFabric application images are stored privately in ACR.

---

## Infrastructure as Code

Azure infrastructure is defined using **Bicep**.

```text
main.bicep
   │
   ├── AKS
   ├── ACR
   ├── Service Bus
   └── APIM

rbac.bicep
   │
   ├── AKS → ACR AcrPull
   ├── GitHub → ACR AcrPush
   └── GitHub → AKS access
```

Environment-specific `.bicepparam` files allow the same Bicep modules to create both production and disposable test environments.

Microsoft Entra External ID configuration is kept separately because the identity tenant exists independently from the main Azure resource group.

### Infrastructure

```text
infra/
├── main.bicep
├── main.bicepparam
├── main.test.bicepparam
├── rbac.bicep
├── configure-apim.ps1
│
├── apim/
│   ├── api-policy.xml
│   ├── orders.swagger.json
│   ├── products.swagger.json
│   └── users.swagger.json
│
└── modules/
    ├── acr.bicep
    ├── aks.bicep
    ├── apim.bicep
    ├── apim-policies.bicep
    ├── servicebus.bicep
    │
    └── identity/
        ├── main.identity.bicep
        ├── configure-identity.ps1
        └── modules/
            ├── backend-app.bicep
            └── frontend-app.bicep
```

---

## CI/CD

CommerceFabric separates **environment deployment** from **application releases**.

### Full environment deployment

`deploy-all.yml` creates or reconciles an environment:

```text
GitHub Actions
      │
      ▼
Azure login using OIDC
      │
      ▼
Bicep → Azure infrastructure
      │
      ▼
Bicep → Azure RBAC
      │
      ▼
Kubernetes manifests → AKS
      │
      ▼
Kubernetes runtime secrets
      │
      ▼
PowerShell → APIM configuration
```

A `bootstrap` mode supports creation of a completely new environment before CommerceFabric application images have been published to its ACR.

### Microservice releases

Each microservice repository owns its CI process:

```text
Code change
   │
   ▼
Test + build
   │
   ▼
Build Docker image
   │
   ▼
Push versioned image → ACR
   │
   ▼
Trigger infra-platform
   │
   ▼
deploy-microservice.yml
   │
   ▼
Rolling update → AKS
```

This keeps application repositories responsible for **building artifacts**, while `infra-platform` owns the **environment and deployment process**.

GitHub authenticates to Azure using **Workload Identity Federation (OIDC)**, avoiding long-lived Azure deployment credentials in GitHub.

---

## API Management

APIM exposes the public CommerceFabric APIs in front of the Kubernetes API Gateway.

`configure-apim.ps1` discovers the API Gateway endpoint and imports the Orders, Products and Users OpenAPI specifications into APIM.

`apim-policies.bicep` then applies shared API policies such as:

- JWT validation
- CORS configuration
- API access policies

This keeps the public API configuration reproducible alongside the rest of the infrastructure.

---

## Kubernetes

AKS hosts:

- API Gateway
- Orders, Products and Users microservices
- MongoDB
- PostgreSQL
- MySQL
- Redis
- RabbitMQ

Useful commands:

```powershell
kubectl get deployments -n commercefabric-namespace
kubectl get pods -n commercefabric-namespace
kubectl rollout status deployment/<deployment-name> -n commercefabric-namespace
```

---

## Secrets & Security

Secrets are not stored in Bicep or committed to source control.

The deployment workflows retrieve or inject runtime secrets into Kubernetes, including the Azure Service Bus connection and Entra application secret.

Azure access from GitHub uses OIDC federation and Azure RBAC.

### Deployment Prerequisites

GitHub Actions requires a Microsoft Entra application configured with **Workload Identity Federation (OIDC)**.

The repository stores its Azure client, tenant and subscription IDs as GitHub secrets; no Azure client secret is required.

The GitHub deployment principal requires subscription-level **Contributor** and **Role Based Access Control Administrator** permissions so that `deploy-all` can create resource groups, provision infrastructure and establish the required Azure RBAC assignments.

This bootstrap identity exists independently from the CommerceFabric resource group, allowing the environment to be recreated after deletion.

---

## Deployment Environments

The same infrastructure definitions support:

- **Production** — the main CommerceFabric environment.
- **Test** — a disposable environment used to validate infrastructure and deployment automation.

The test environment has been successfully recreated through the GitHub Actions/Bicep deployment flow, validating the infrastructure recovery process.

The External ID tenant is managed separately and survives deletion of the main Azure resource group.

---

## Status

Implemented:

- Bicep provisioning for AKS, ACR, Service Bus and APIM
- Automated Azure RBAC
- Production/test parameterisation
- GitHub OIDC authentication
- Full environment bootstrap workflow
- Incremental microservice deployment workflow
- Kubernetes runtime secret creation
- APIM OpenAPI import and policy deployment
- Disposable environment recovery testing

Current work focuses on final end-to-end application validation and deployment hardening.