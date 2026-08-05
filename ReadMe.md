# TODO

- orders microservice is currently failing as it requires the service manifests so it can actually communicate with those services as ight now it gives BrokerUnreachableException 
- Add a diagram explaining the flow
- Add a diagram explaining how the deployment + service manifests are used within aks to deploy and allow the services to communicate with one another

# infra-platform (CommerceFabric)

This repository is the **system entry point** for the CommerceFabric microservices ecosystem.

It defines how all services, databases, and infrastructure components run together using Docker Compose.

To run the project use 
```bash
docker-compose up
```

To stop the project use 
```bash
docker-compose down
```

---

## Pushing Docker Compose Images to Azure Container Registry

The `docker-compose.yaml` file pulls the other microservices and supporting services from Docker Hub. This means that after running Docker Compose, all of the required images are available locally.

These images can then be tagged and pushed to my Azure Container Registry (ACR).

### 1. Pull and build all images

If the images have not already been downloaded/built locally:

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
* Build the Orders microservice
* Build the API Gateway

Check the locally available images with:

```bash
docker images
```

### 2. Log in to Azure Container Registry

My Azure Container Registry is:

```text
commercefabricregistry.azurecr.io
```

Log in using:

```bash
az acr login --name commercefabricregistry
```

### 3. Tag the images

Tag the application images with the ACR registry name:

```bash
docker tag ordersmicroserviceapi:latest commercefabricregistry.azurecr.io/orders-microservice:latest

docker tag apigateway:latest commercefabricregistry.azurecr.io/apigateway:latest

docker tag danielmusselwhite/commercefabric_user_microservice:1.0.0 commercefabricregistry.azurecr.io/users-microservice:latest

docker tag danielmusselwhite/commercefabric_product_microservice:1.0.0 commercefabricregistry.azurecr.io/products-microservice:latest

docker tag mongo:latest commercefabricregistry.azurecr.io/mongo:latest

docker tag postgres:18.0 commercefabricregistry.azurecr.io/postgres:18.0

docker tag mysql:9.7.1 commercefabricregistry.azurecr.io/mysql:9.7.1

docker tag redis:latest commercefabricregistry.azurecr.io/redis:latest

docker tag rabbitmq:4.3.3-management commercefabricregistry.azurecr.io/rabbitmq:4.3.3-management
```

> **Note:** The exact local image names can be checked with `docker images`. If Docker Compose has generated a different image name, use that name when running `docker tag`.

### 4. Push the images to ACR

Push the application images:

```bash
docker push commercefabricregistry.azurecr.io/orders-microservice:latest

docker push commercefabricregistry.azurecr.io/apigateway:latest

docker push commercefabricregistry.azurecr.io/users-microservice:latest

docker push commercefabricregistry.azurecr.io/products-microservice:latest

docker push commercefabricregistry.azurecr.io/mongo:latest

docker push commercefabricregistry.azurecr.io/postgres:18.0

docker push commercefabricregistry.azurecr.io/mysql:9.7.1

docker push commercefabricregistry.azurecr.io/redis:latest

docker push commercefabricregistry.azurecr.io/rabbitmq:4.3.3-management
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

---

# infra-platform (CommerceFabric)

This repository is the **system entry point** for the CommerceFabric microservices ecosystem.

It defines how all services, databases, and infrastructure components run together using Docker Compose.

To run the project use:

```bash
docker-compose up
```

To stop the project use:

```bash
docker-compose down
```
---

## Pushing Docker Compose Images to Azure Container Registry

The `docker-compose.yaml` file pulls the other microservices and supporting services from Docker Hub. This means that after running Docker Compose, all of the required images are available locally.

These images can then be tagged and pushed to my Azure Container Registry (ACR).

### 1. Pull all images

If the images have not already been downloaded/built locally:

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

### 2. Log in to Azure Container Registry

My Azure Container Registry is:

```text
commercefabricregistry.azurecr.io
```

Log in using:

```bash
az acr login --name commercefabricregistry
```

Important: This login only gives the local machine access to ACR. It does not give AKS permission to pull images from ACR. AKS access is configured separately in Step 5.

### 3. Tag the images

Tag the application images with the ACR registry name:
Note: Redis and RabitMQ doesn't need to be tagged or pushed as the deployment manifest for AKS specifies thems as coming from dockerhub

```bash
docker tag ordersmicroserviceapi:latest commercefabricregistry.azurecr.io/orders-microservice:latest

docker tag apigateway:latest commercefabricregistry.azurecr.io/apigateway:latest

docker tag danielmusselwhite/commercefabric_user_microservice:1.0.0 commercefabricregistry.azurecr.io/users-microservice:latest

docker tag danielmusselwhite/commercefabric_product_microservice:1.0.0 commercefabricregistry.azurecr.io/products-microservice:latest

docker tag mongo:latest commercefabricregistry.azurecr.io/mongo:latest

docker tag postgres:18.0 commercefabricregistry.azurecr.io/postgres:18.0

docker tag mysql:9.7.1 commercefabricregistry.azurecr.io/mysql:9.7.1
```

> **Note:** The exact local image names can be checked with `docker images`. If Docker Compose has generated a different image name, use that name when running `docker tag`.

### 4. Push the images to ACR

Push the application images:

```bash
docker push commercefabricregistry.azurecr.io/orders-microservice:latest

docker push commercefabricregistry.azurecr.io/apigateway:latest

docker push commercefabricregistry.azurecr.io/users-microservice:latest

docker push commercefabricregistry.azurecr.io/products-microservice:latest

docker push commercefabricregistry.azurecr.io/mongo:latest

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

---

## 6. Deploy the Kubernetes resources

Once the images are available in ACR and AKS has permission to pull them, deploy the Kubernetes manifests:

```bash
kubectl apply -f ./aks
```

Check the deployments:

```bash
kubectl get deployments -n commercefabric-namespace
```

Check the pods:

```bash
kubectl get pods -n commercefabric-namespace
```

A healthy deployment should eventually show pods similar to:

```text
NAME                                             READY   STATUS    RESTARTS
apigateway-deployment-...                       1/1     Running   0
orders-microservice-deployment-...              1/1     Running   0
products-microservice-deployment-...            1/1     Running   0
users-microservice-deployment-...               1/1     Running   0
mysql-deployment-...                             1/1     Running   0
postgres-deployment-...                          1/1     Running   0
mongodb-deployment-...                           1/1     Running   0
redis-deployment-...                             1/1     Running   0
rabbitmq-deployment-...                          1/1     Running   0
```

---

## 7. Check Kubernetes Services

After the images have successfully started, check the Kubernetes Services:

```bash
kubectl get services -n commercefabric-namespace
```

Services provide the DNS names that the microservices use to communicate with one another inside the Kubernetes cluster.

For example, if a Service is named:

```text
users-microservice
```

another pod can communicate with it using:

```text
users-microservice:8080
```

Environment variables in the microservices should therefore reference the **Kubernetes Service name**, rather than the Deployment name.

For example:

```yaml
- name: UsersMicroserviceName
  value: users-microservice

- name: ProductsMicroserviceName
  value: products-microservice
```

The exact values should match the names defined in the Kubernetes Service manifests.

---

## 8s. Restart workloads after configuration changes

If the Kubernetes manifests or image configuration are changed, apply them again:

```bash
kubectl apply -f ./aks
```

If necessary, restart the deployments:

```bash
kubectl rollout restart deployment -n commercefabric-namespace
```

Then monitor the pods:

```bash
kubectl get pods -n commercefabric-namespace -w
```
