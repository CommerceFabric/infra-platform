# infra-platform (CommerceFabric)

This repository is the **system entry point** for the CommerceFabric microservices ecosystem.

It defines how all services, databases, and infrastructure components are run and deployed together, both locally using Docker Compose and in Azure Kubernetes Service (AKS).

---

## Run Locally with Docker Compose

To start the CommerceFabric environment locally:

```bash
docker-compose up
```

To stop the environment:

```bash
docker-compose down
```

---

## Push Docker Compose Images to Azure Container Registry

If any Docker images have been updated, they need to be pushed to Azure Container Registry (ACR) so that AKS can pull and run the latest versions.

See:

* [Push images to ACR](./docs/PushDockerComposeImages.md)

---

## Deploy the Kubernetes Resources

Once the required images are available in ACR and AKS has permission to pull them, deploy the Kubernetes manifests located in [`aks`](./aks/):

```bash
kubectl apply -f ./aks
```

For more information on how this works please see: [Kubernetes manifests documentation](./docs/KubernetesManifestsHowTo.md)

For database seed behavior, persistence expectations, and clean reset steps, see: [Database seeding and persistence guide](./docs/DatabaseSeedingAndPersistence.md)

For a simple troubleshooting summary of issues fixed in this project and repeatable checks, see: [Kubernetes troubleshooting guide](./docs/KubernetesTroubleshooting.md)

---

## Verify the Deployment

After applying the manifests, verify that the resources have started successfully.

### Check the Deployments

```bash
kubectl get deployments -n commercefabric-namespace
```

### Check the Pods

```bash
kubectl get pods -n commercefabric-namespace
```

### Check the Kubernetes Services

```bash
kubectl get services -n commercefabric-namespace
```

The Services are particularly important because they provide the stable DNS names that microservices use to communicate with one another inside the Kubernetes cluster.

---

## Restart Workloads After Configuration Changes

If Kubernetes manifests or image configuration are changed, apply the manifests again:

```bash
kubectl apply -f ./aks
```

Note: completed Kubernetes `Job` resources (for example database seed jobs) do not automatically rerun on a plain `kubectl apply`. Recreate the Job if you need to run it again.

If necessary, restart the deployments:

```bash
kubectl rollout restart deployment -n commercefabric-namespace
```

Then monitor the pods:

```bash
kubectl get pods -n commercefabric-namespace -w
```

---