# infra-platform (CommerceFabric)

The **infra-platform** repository contains the infrastructure-as-code, Kubernetes manifests, and deployment automation required to run the CommerceFabric platform on **Microsoft Azure Kubernetes Service (AKS)**.

This repository is responsible for the **continuous deployment (CD)** side of the platform. Microservice repositories are responsible for building, testing, and publishing container images, while this repository manages deploying those images into the AKS environment.

This repository manages:

- Kubernetes manifests for platform services
- Application deployments and service configuration
- Azure Kubernetes Service (AKS) deployment configuration
- GitHub Actions deployment workflows
- Azure authentication configuration using Workload Identity Federation (OIDC)
- Deployment documentation and operational guidance

The CommerceFabric platform runs as a collection of independent Kubernetes workloads, with each microservice deployed separately into the `commercefabric-namespace` Kubernetes namespace.

> ℹ **Note:** if you are deploying the platform for the first time, ensure you have set up the required Azure resources: [SettingUpAzureResources](./docs/SettingUpAzureResources.md)

> ℹ **Note:** if you are updating versions of external servicies (mongodb, postgresql, mysql, redis, rabbitmq, etc.) you will need to [Manually Push Docker Compose Images](./docs/PushDockerComposeImages.md)

---

# Repository Structure

```
infra-platform/
│
├── aks/             # Kubernetes manifests
|
├── .github/
│   └── workflows/   # GitHub Actions CI/CD workflows
```

---

# GitHub Actions CI/CD Workflows

The repository uses GitHub Actions to automate deployments into Azure Kubernetes Service.

Deployment workflows support:

- Building and deploying microservices
- Updating Kubernetes deployments with new container images
- Rolling out new versions into AKS
- Verifying successful deployments

Currently supported services:

- Orders microservice
- Products microservice
- Users microservice

This is triggered either:

- Manually by specifying the service name and the container image tag to deploy via the GitHub Actions workflow dispatch interface.
- Automatically, as part of the CI/CD pipeline. As when a microservice repo is updated, its CI pipeline pushes the image to the Azure Container Registry and then triggers the deployment workflow in this repository to perform the CD by updating the Kubernetes deployment with the new image.

## Diagram of the CI/CD flow

```
                         ┌──────────────────────────┐
                         │  Developer pushes code   │
                         │  to microservice repo    │
                         └────────────┬─────────────┘
                                      │
                                      ▼
                         ┌──────────────────────────┐
                         │   GitHub Actions CI      │
                         │                          │
                         │  - Build Docker image    │
                         │  - Run tests             │
                         │  - Tag image with SHA    │
                         └────────────┬─────────────┘
                                      │
                                      ▼
              ┌──────────────────────────────────────────┐
              │ Azure Container Registry (ACR)           │
              │                                          │
              │ commercefabricregistry.azurecr.io        │
              │                                          │
              │ orders-microservice:<version>            │
              │ products-microservice:<version>          │
              │ users-microservice:<version>             │
              └──────────────────┬───────────────────────┘
                                 │
                                 │ repository_dispatch
                                 │
                                 │ Payload:
                                 │ {
                                 │   service: "orders",
                                 │   image_tag: "8ce72d29..."
                                 │ }
                                 ▼
              ┌──────────────────────────────────────────┐
              │ GitHub Actions Deployment Workflow       │
              │                                          │
              │ Deploy to AKS                            │
              │                                          │
              │ 1. Authenticate to Azure (OIDC)          │
              │ 2. Connect to AKS                        │
              │ 3. Update Kubernetes deployment image    │
              └──────────────────┬───────────────────────┘
                                 │
                                 ▼
              ┌──────────────────────────────────────────┐
              │ Azure Kubernetes Service (AKS)           │
              │                                          │
              │ Namespace: commercefabric-namespace      │
              │                                          │
              │ orders-microservice-deployment           │
              │        │                                 │
              │        ▼                                 │
              │ Pull image:                              │
              │ commercefabricregistry.azurecr.io/       │
              │ orders-microservice:<version>            │
              │                                          │
              │ products-microservice-deployment         │
              │ users-microservice-deployment            │
              └──────────────────────────────────────────┘
```

---

## Azure Authentication

GitHub Actions authenticates with Azure using **Workload Identity Federation (OIDC)**.

This provides secure authentication without requiring long-lived Azure credentials or service principal secrets stored in GitHub.

The deployment flow is:

1. GitHub Actions requests an OIDC token from GitHub.
2. Azure validates the federated identity credential.
3. The workflow authenticates against Azure.
4. The workflow connects to AKS.
5. Kubernetes resources are deployed or updated.

---

# Azure Kubernetes Service (AKS)

The CommerceFabric platform runs on Azure Kubernetes Service.

Each microservice is deployed as a Kubernetes Deployment within:

```
commercefabric-namespace
```

The main application services are:

| Service | Kubernetes Deployment |
|---|---|
| Orders | `orders-microservice-deployment` |
| Products | `products-microservice-deployment` |
| Users | `users-microservice-deployment` |

---

# Deployment Verification

After deployment, you can verify the running workloads using:

```powershell
kubectl get deployments -n commercefabric-namespace; # view deployments

kubectl get pods -n commercefabric-namespace; # view pods

kubectl describe pod <pod-name> -n commercefabric-namespace # check container image running on a pod is the expected one

kubectl rollout status deployment/<deployment-name> -n commercefabric-namespace # check rollout status of a deployment
```

---

# Manual Deployment

If you need to manually deploy or recreate the platform infrastructure, follow the deployment guide:

[Manual deployment and setup guide](./docs/ManualDeploymentGuide.md)

---

# Security Notes

> ⚠️ **Kubernetes Secrets**
>
> Kubernetes manifests currently contain secrets in plaintext for development and demonstration purposes.
>
> In a production environment, secrets should be stored securely using a dedicated secrets management solution.

---

> ✔ **GitHub Actions Secrets**
>
> Deployment workflows use GitHub Actions Secrets for sensitive configuration values such as Azure authentication details.
>
> These secrets are protected by GitHub and are not exposed directly in workflow files.

---

> ℹ️ **Deploy-All workflow**
>
> A separate **deploy-all** workflow is available for initial platform deployments or situations where all Kubernetes resources need to be recreated.
>
> Unlike the normal microservice deployment workflow, this workflow does not receive a specific image tag from a microservice repository. Instead, it applies all Kubernetes manifests from the `aks/` directory using `kubectl apply`.
>
> The workflow deploys all configured services using their manifest-defined container image versions. If the manifests reference the `latest` image tag, Kubernetes will use the latest available image from Azure Container Registry.
>
> This workflow is intended for manual use from the GitHub Actions interface and is not triggered automatically by individual microservice repositories.