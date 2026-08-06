# Kubernetes Manifests Explained

The Kubernetes manifests define how the CommerceFabric platform runs inside Azure Kubernetes Service (AKS).

They describe:

- How microservices are deployed
- How services communicate internally
- How databases are initialised
- How external traffic reaches the platform

---

# Kubernetes Resources

## Deployments

Deployments manage the lifecycle of application Pods.

They define:

- Container image to run
- Number of replicas
- Environment variables
- Container ports
- Resource settings

Example:

```

Deployment
|
v
Pod(s)
|
v
Container running microservice

```

---

## Services

Services provide stable network access to Pods.

Pods are temporary and can change IP addresses, so microservices communicate using Service names instead of Pod IP addresses.

The platform uses:

| Service Type | Purpose |
|---|---|
| LoadBalancer | Exposes the API Gateway externally |
| ClusterIP | Internal communication between microservices |

Example:

```

External Client
|
v
API Gateway
(LoadBalancer)
|
v
Products Service
(ClusterIP)
|
v
Products Pod

````

The API Gateway is the only public entry point. Internal microservices are not exposed directly to the internet.

---

# Kubernetes DNS and Service Names

Microservices communicate using Kubernetes Service names.

Example Service:

```yaml
apiVersion: v1
kind: Service
metadata:
  name: products-microservice
````

The Service name becomes the internal hostname:

```
products-microservice:8080
```

Kubernetes DNS automatically resolves this hostname to the correct Service.

Traffic flow:

```
API Gateway
      |
      | Host: products-microservice
      |
      v
Kubernetes DNS
      |
      v
products-microservice Service
      |
      v
Products Pod(s)
```

---

# Ocelot API Gateway Routing

The API Gateway uses Ocelot to forward requests to internal microservices.

Example:

```json
{
  "DownstreamHostAndPorts": [
    {
      "Host": "products-microservice",
      "Port": 8080
    }
  ]
}
```

The `Host` value must match the Kubernetes Service name.

These must stay aligned:

```
Kubernetes Service          Ocelot Configuration
------------------          --------------------
products-microservice  <--> "Host": "products-microservice"
```

If they do not match, Kubernetes DNS cannot find the service and requests will fail.

---

# Complete Request Flow

Example request:

```
GET http://<API-GATEWAY-IP>/products
```

Flow:

```
External Client
      |
      v
API Gateway LoadBalancer
      |
      v
Ocelot Routing
      |
      | products-microservice:8080
      |
      v
Kubernetes Service
      |
      v
Products Pod
```

The client never communicates directly with the Products microservice.

---

# Database Seeding

Database initialisation is handled using Kubernetes resources rather than Docker Compose startup behaviour.

Each database uses:

* Deployment - runs the database
* Service - provides internal access
* ConfigMap - stores seed scripts
* Job - executes the seed process

---

## MySQL

Resources:

```
mysql-deployment.yaml
mysql.service.yaml
mysql-seed-configmap.yaml
mysql-seed-job.yaml
```

Deploy:

```bash
kubectl apply -f aks/mysql-deployment.yaml
kubectl apply -f aks/mysql.service.yaml
kubectl apply -f aks/mysql-seed-configmap.yaml
kubectl apply -f aks/mysql-seed-job.yaml
```

Verify:

```bash
kubectl exec -n commercefabric-namespace deployment/mysql-deployment -- \
mysql -uroot -padmin -e "SHOW TABLES IN productDB;"
```

---

## PostgreSQL

Resources:

```
postgres-deployment.yaml
postgres.service.yaml
postgres-seed-configmap.yaml
postgres-seed-job.yaml
```

Deploy:

```bash
kubectl apply -f aks/postgres-deployment.yaml
kubectl apply -f aks/postgres.service.yaml
kubectl apply -f aks/postgres-seed-configmap.yaml
kubectl apply -f aks/postgres-seed-job.yaml
```

Verify:

```bash
kubectl exec -n commercefabric-namespace deployment/postgres-deployment -- \
psql -U postgres -d commercefabricUsers -c "\dt"
```

---

## MongoDB

Resources:

```
mongodb-deployment.yaml
mongodb.service.yaml
mongodb-seed-configmap.yaml
mongodb-seed-job.yaml
```

Deploy:

```bash
kubectl apply -f aks/mongodb-deployment.yaml
kubectl apply -f aks/mongodb.service.yaml
kubectl apply -f aks/mongodb-seed-configmap.yaml
kubectl apply -f aks/mongodb-seed-job.yaml
```

Verify:

```bash
kubectl exec -n commercefabric-namespace deployment/mongodb-deployment -- \
mongosh --quiet --eval "db.getSiblingDB('OrdersDb').orders.countDocuments()"
```

---

# Summary

The important relationships are:

```
Deployment
    |
    v
Pod
    |
    v
Service
    |
    v
Other services communicate using Service names
```

For this platform:

* **Deployment** runs microservices.
* **Service** provides stable internal networking.
* **LoadBalancer** exposes the API Gateway.
* **ClusterIP** keeps internal services private.
* **Ocelot** routes API requests.
* **Service names** provide the internal DNS names.
* **Database Jobs** initialise database data.