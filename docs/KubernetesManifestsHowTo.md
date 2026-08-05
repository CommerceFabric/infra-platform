# Kubernetes Manifests Explained

The Kubernetes manifests define how the microservices are deployed and how they communicate within the AKS cluster.

This repository primarily uses the following Kubernetes resource types:

## Deployments

**Deployment manifests** define how each microservice runs in AKS.

They specify things such as:

* Which Docker image should be run
* How many replicas should be created
* Container configuration
* Environment variables
* Container ports
* Resource requests and limits

A Deployment manages the lifecycle of the Pods running the microservice.

## ConfigMaps

**ConfigMap manifests** store configuration or seed script content so it can be mounted into Pods at runtime.

In this repository, ConfigMaps are used to hold database seed scripts for AKS database initialization Jobs.

## Jobs

**Job manifests** run one-off tasks to completion.

In this repository, Jobs are used to apply database seed scripts in AKS after the database services are available.

## Services

**Service manifests** provide a stable network endpoint for the Pods running a microservice.

They allow other workloads to communicate with a microservice without needing to know the IP address of an individual Pod.

In this repository:

* The **API Gateway** uses a `LoadBalancer` Service and is externally accessible.
* The other microservices use `ClusterIP` Services and are only accessible from within the Kubernetes cluster.

The overall traffic flow looks like this:

```text
External Client
      │
      │ HTTP request
      ▼
┌─────────────────────┐
│    API Gateway      │
│    LoadBalancer     │
│    External IP      │
└──────────┬──────────┘
           │
           │ Internal Kubernetes traffic
           ▼
┌─────────────────────┐
│ Products Service    │
│ ClusterIP           │
└──────────┬──────────┘
           │
           ▼
     Products Pod(s)
```

The API Gateway is therefore the public entry point. The individual microservices do not need to be exposed directly to the internet.

## Service Names and Kubernetes DNS

Microservices communicate with each other using **Kubernetes Service names**, rather than Pod IP addresses.

For example, suppose the Products microservice has a Kubernetes Service defined like this:

```yaml
apiVersion: v1
kind: Service
metadata:
  name: products-microservice
spec:
  type: ClusterIP
  selector:
    app: products-microservice
  ports:
    - port: 8080
      targetPort: 8080
```

The important part here is:

```yaml
metadata:
  name: products-microservice
```

This is the **Kubernetes Service name**.

Other workloads inside the cluster can use this name to communicate with the Products microservice:

```text
products-microservice:8080
```

Kubernetes DNS resolves `products-microservice` to the internal Service, which then routes the request to one of the matching Products Pods.

### How Ocelot uses the Service name

The API Gateway in this repository uses **Ocelot** to determine where requests should be forwarded.

For example, the Ocelot configuration might contain:

```json
{
  "DownstreamPathTemplate": "/api/products",
  "DownstreamHostAndPorts": [
    {
      "Host": "products-microservice",
      "Port": 8080
    }
  ]
}
```

Here, Ocelot is configured with:

```text
Host = products-microservice
Port = 8080
```

The `Host` value is important because it needs to match the Kubernetes Service name.

The relationship is:

```text
                 External Request
                       │
                       │ GET /products
                       ▼
              ┌──────────────────┐
              │   API Gateway     │
              │   LoadBalancer    │
              └────────┬─────────┘
                       │
                       │ Ocelot
                       │
                       │ Host:
                       │ products-microservice
                       ▼
              ┌──────────────────┐
              │ Kubernetes DNS   │
              └────────┬─────────┘
                       │
                       │ resolves
                       ▼
              ┌──────────────────┐
              │ products-        │
              │ microservice     │
              │ ClusterIP        │
              └────────┬─────────┘
                       │
                       ▼
                Products Pod(s)
```

### Why the names must match

The Kubernetes Service might be called:

```yaml
metadata:
  name: products-microservice
```

Therefore Ocelot should use:

```json
{
  "Host": "products-microservice",
  "Port": 8080
}
```

These two names are connected:

```text
Kubernetes Service             Ocelot
------------------             -------------------------
products-microservice   <───>  "Host": "products-microservice"
```

If the Kubernetes Service were accidentally renamed to:

```yaml
metadata:
  name: product-microservice
```

but Ocelot still contained:

```json
{
  "Host": "products-microservice",
  "Port": 8080
}
```

then Ocelot would try to send the request to:

```text
products-microservice
```

Kubernetes DNS would look for a Service with that name, but the Service would actually be called:

```text
product-microservice
```

The hostname would therefore not resolve and the request would fail.

This is why **the Service names in the Kubernetes manifests and the hostnames configured in Ocelot need to stay in sync**.

### Complete example

For example, a request from outside the cluster might look like:

```text
GET http://<API-GATEWAY-EXTERNAL-IP>/products
```

The flow is:

```text
External Client
      │
      │ GET /products
      ▼
API Gateway
      │
      │ Ocelot determines the downstream service
      │
      │ Host: products-microservice
      │ Port: 8080
      ▼
Kubernetes DNS
      │
      │ resolves products-microservice
      ▼
Products Service
      │
      │ ClusterIP
      ▼
Products Pod
```

The important thing to understand is that the external client **does not communicate directly with the Products Pod**.

Instead:

1. The request enters the AKS cluster through the API Gateway's `LoadBalancer`.
2. Ocelot determines which microservice should handle the request.
3. Ocelot uses the configured hostname, such as `products-microservice`.
4. Kubernetes DNS resolves that name to the corresponding Kubernetes Service.
5. The Service routes the request to one of the Products Pods.

### In short

* **Deployment** → runs and manages the Pods.
* **Service** → provides a stable network endpoint for the Pods.
* **LoadBalancer** → exposes the API Gateway externally.
* **ClusterIP** → keeps the other microservices internal to the cluster.
* **Ocelot** → determines where API Gateway requests should be forwarded.
* **Service name** → provides the hostname used for internal communication.
* **Ocelot hostname and Kubernetes Service name must match**.

For this repository, the important relationship to remember is:

```text
Ocelot
  │
  │ "products-microservice"
  ▼
Kubernetes Service
  │
  │ products-microservice
  ▼
Products Pod(s)
```

## Database Seeding in AKS

Database seeding for AKS should be handled by Kubernetes resources, not by assuming Docker Compose runtime initialization is included in pushed base database images.

For MySQL, use:

* `aks/mysql-deployment.yaml`
* `aks/mysql.service.yaml`
* `aks/mysql-seed-configmap.yaml`
* `aks/mysql-seed-job.yaml`

Recommended apply order:

```bash
kubectl apply -f aks/mysql-deployment.yaml
kubectl apply -f aks/mysql.service.yaml
kubectl apply -f aks/mysql-seed-configmap.yaml
kubectl apply -f aks/mysql-seed-job.yaml
```

Verify seed results:

```bash
kubectl exec -n commercefabric-namespace deployment/mysql-deployment -- mysql -uroot -padmin -e "SHOW TABLES IN productDB; SELECT COUNT(*) AS ProductCount FROM productDB.Products;"
```

For Postgres, use:

* `aks/postgres-deployment.yaml`
* `aks/postgres.service.yaml`
* `aks/postgres-seed-configmap.yaml`
* `aks/postgres-seed-job.yaml`

Recommended apply order:

```bash
kubectl apply -f aks/postgres-deployment.yaml
kubectl apply -f aks/postgres.service.yaml
kubectl apply -f aks/postgres-seed-configmap.yaml
kubectl apply -f aks/postgres-seed-job.yaml
```

Verify seed results:

```bash
kubectl exec -n commercefabric-namespace deployment/postgres-deployment -- psql -U postgres -d commercefabricUsers -c "\dt"
```

For MongoDB, use:

* `aks/mongodb-deployment.yaml`
* `aks/mongodb.service.yaml`
* `aks/mongodb-seed-configmap.yaml`
* `aks/mongodb-seed-job.yaml`

Recommended apply order:

```bash
kubectl apply -f aks/mongodb-deployment.yaml
kubectl apply -f aks/mongodb.service.yaml
kubectl apply -f aks/mongodb-seed-configmap.yaml
kubectl apply -f aks/mongodb-seed-job.yaml
```

Verify seed results:

```bash
kubectl exec -n commercefabric-namespace deployment/mongodb-deployment -- mongosh --quiet --eval "db.getSiblingDB('OrdersDb').orders.countDocuments()"
```
