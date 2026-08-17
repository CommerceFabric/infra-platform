# Pushing Docker Compose Images to Azure Container Registry

> ℹ First, ensure you have set up the required Azure resources: [SettingUpAzureResources](./SettingUpAzureResources.md)

Important for database images: runtime seed data created by Docker Compose init mounts is not baked into the base image tags pushed to ACR. In AKS, seed scripts should be applied with Kubernetes-native resources (for example, ConfigMap + Job manifests).

## 1. Pull all images

Pulls the latest version of all images defined in the `docker-compose.yaml` file:

```bash
docker-compose -f docker-compose.yaml pull
```

This will:

* Pull the Users microservice from Docker Hub
* Pull the Products microservice from Docker Hub
* Pull MongoDB
* Pull PostgreSQL
* Pull MySQL
* Pull Redis
* Pull RabbitMQ
* Pull the Orders microservice
* Pull the API Gateway

Check the locally available images with:

```bash
docker images
```

## 2. Log in to Azure Container Registry

My Azure Container Registry is:

```text
commercefabricregistry.azurecr.io
```

Log in using:

```bash
az acr login --name commercefabricregistry
```

Important: This login only gives the local machine access to ACR. It does not give AKS permission to pull images from ACR. AKS access is configured separately in Step 5.

## 3. Tag the images

Tag the application images with the ACR registry name.
Note: Redis and RabbitMQ do not need to be tagged or pushed because the AKS deployment manifests reference Docker Hub images for them.

```powershell
# Loading the versions from the .env file
$ORDER_VERSION = (Get-Content .env | Where-Object { $_ -match '^ORDER_VERSION=' }) -replace '^ORDER_VERSION=', ''
$API_GATEWAY_VERSION = (Get-Content .env | Where-Object { $_ -match '^API_GATEWAY_VERSION=' }) -replace '^API_GATEWAY_VERSION=', ''
$USER_VERSION = (Get-Content .env | Where-Object { $_ -match '^USER_VERSION=' }) -replace '^USER_VERSION=', ''
$PRODUCT_VERSION = (Get-Content .env | Where-Object { $_ -match '^PRODUCT_VERSION=' }) -replace '^PRODUCT_VERSION=', ''

# Tagging the local images with the ACR registry name
docker tag "danielmusselwhite/commercefabric_order_microservice:$ORDER_VERSION" "commercefabricregistry.azurecr.io/orders-microservice:latest"

docker tag "danielmusselwhite/commercefabric_api_gateway:$API_GATEWAY_VERSION" "commercefabricregistry.azurecr.io/apigateway:latest"

docker tag "danielmusselwhite/commercefabric_user_microservice:$USER_VERSION" "commercefabricregistry.azurecr.io/users-microservice:latest"

docker tag "danielmusselwhite/commercefabric_product_microservice:$PRODUCT_VERSION" "commercefabricregistry.azurecr.io/products-microservice:latest"

docker tag "mongo:8.3.7" "commercefabricregistry.azurecr.io/mongo:8.3.7"

docker tag "postgres:18.0" "commercefabricregistry.azurecr.io/postgres:18.0"

docker tag "mysql:9.7.1" "commercefabricregistry.azurecr.io/mysql:9.7.1"
```

> **Note:** The exact local image names can be checked with `docker images`. If Docker Compose has generated a different image name, use that name when running `docker tag`.

## 4. Push the images to ACR

Push the application images:

```bash
docker push commercefabricregistry.azurecr.io/orders-microservice:latest

docker push commercefabricregistry.azurecr.io/apigateway:latest

docker push commercefabricregistry.azurecr.io/users-microservice:latest

docker push commercefabricregistry.azurecr.io/products-microservice:latest

docker push commercefabricregistry.azurecr.io/mongo:8.3.7

docker push commercefabricregistry.azurecr.io/postgres:18.0

docker push commercefabricregistry.azurecr.io/mysql:9.7.1
```

The images can then be viewed in the Azure Container Registry:

```bash
az acr repository list --name commercefabricregistry --output table
```

The application images will be available as:

```text
commercefabricregistry.azurecr.io/orders-microservice:latest
commercefabricregistry.azurecr.io/apigateway:latest
commercefabricregistry.azurecr.io/users-microservice:latest
commercefabricregistry.azurecr.io/products-microservice:latest
```

These images can then be referenced by the Kubernetes deployments running in AKS.

For this repository, seeding in AKS is handled by:

* `aks/mysql-seed-configmap.yaml`
* `aks/mysql-seed-job.yaml`
* `aks/postgres-seed-configmap.yaml`
* `aks/postgres-seed-job.yaml`
* `aks/mongodb-seed-configmap.yaml`
* `aks/mongodb-seed-job.yaml`

## 5. Grant AKS permission to pull images from ACR

The AKS cluster needs permission to pull private images from the Azure Container Registry.

My AKS cluster is:

```text
CommerceFabric-aks-cluster
```

The resource group is:

```text
CommerceFabric-ResourceGroup
```

Attach the ACR to the AKS cluster:

```bash
az aks update \
  --name CommerceFabric-aks-cluster \
  --resource-group CommerceFabric-ResourceGroup \
  --attach-acr commercefabricregistry
```

This grants the AKS cluster's kubelet identity permission to pull images from the ACR.

### Verify the AKS-to-ACR connection

Run:

```bash
az aks check-acr \
  --name CommerceFabric-aks-cluster \
  --resource-group CommerceFabric-ResourceGroup \
  --acr commercefabricregistry.azurecr.io
```

The check should succeed before deploying the Kubernetes workloads.

> **Important:** `az acr login` from Step 2 authenticates the local development machine. `az aks update --attach-acr` configures the separate permission required by AKS to pull private container images.
