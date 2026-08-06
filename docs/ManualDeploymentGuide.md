# Manual Deployment Guide

This guide provides instructions for manually deploying the CommerceFabric platform to Azure Kubernetes Service (AKS) using the Kubernetes manifests in the `aks` directory.

For more information on specific parts, please see:
* [How to set up the Kubernetes manifests](./KubernetesManifestsHowTo.md)
* [How the Database seeding works](./DatabaseSeedingAndPersistence.md)
* [How to troubleshoot Kubernetes issues](./KubernetesTroubleshooting.md)


## 1. Push Images to Azure Container Registry (ACR)

If Docker images have changed, push the updated images to Azure Container Registry so AKS can pull them.

See:

- [Push images to ACR](./PushDockerComposeImages.md)

---

## 2. Deploy Kubernetes Resources

Deploy the Kubernetes manifests from the `aks` directory:

```bash
kubectl apply -f ./aks
````

---

## 3. Verify the Deployment

Check that the workloads are running:

### Deployments

```bash
kubectl get deployments -n commercefabric-namespace
```

### Pods

```bash
kubectl get pods -n commercefabric-namespace
```

### Services

```bash
kubectl get services -n commercefabric-namespace
```

Services provide the internal Kubernetes DNS names used by microservices to communicate.

---

## 4. Apply Changes

After changing manifests or image configuration, redeploy:

```bash
kubectl apply -f ./aks
```

To restart running deployments:

```bash
kubectl rollout restart deployment -n commercefabric-namespace
```

Monitor the rollout:

```bash
kubectl get pods -n commercefabric-namespace -w
```

> Note: Kubernetes Jobs (such as database seed jobs) do not rerun when using `kubectl apply`. Delete and recreate the Job if it needs to run again.