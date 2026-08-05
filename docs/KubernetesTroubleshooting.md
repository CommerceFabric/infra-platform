# Kubernetes Troubleshooting (What I Fixed and How to Repeat It)

This guide covers some issues I encountered while deploying the CommerceFabric microservices to AKS, and how I fixed them.

---

## 1) Database seed data was missing in AKS

### Symptom

- `SHOW DATABASES;` did not show expected seeded structures
- So any services that relied on any database data failed to work correctly as the database and tables were missing.

### Root cause

In Docker Compose, seed scripts mounted at runtime and executed inside running containers. 
That runtime data was not baked into the base database images pushed to ACR.

In AKS, MySQL/Postgres/Mongo deployments initially did not have Kubernetes-native seed execution.

### What I changed

I moved seeding to AKS-native resources for each database:

- MySQL: ConfigMap + Job
- PostgreSQL: ConfigMap + Job
- MongoDB: ConfigMap + Job

Files added/used:

- `aks/mysql-seed-configmap.yaml`
- `aks/mysql-seed-job.yaml`
- `aks/postgres-seed-configmap.yaml`
- `aks/postgres-seed-job.yaml`
- `aks/mongodb-seed-configmap.yaml`
- `aks/mongodb-seed-job.yaml`

### Verify seeding

MySQL:

```bash
kubectl exec -n commercefabric-namespace deployment/mysql-deployment -- mysql -uroot -padmin -e "SHOW TABLES IN productDB; SELECT COUNT(*) AS ProductCount FROM productDB.Products;"
```

PostgreSQL:

```bash
kubectl exec -n commercefabric-namespace deployment/postgres-deployment -- psql -U postgres -d commercefabricUsers -c "SELECT COUNT(*) AS user_count FROM public.users;"
```

MongoDB:

```bash
kubectl exec -n commercefabric-namespace deployment/mongodb-deployment -- mongosh --quiet --eval "db.getSiblingDB('OrdersDb').orders.countDocuments()"
```

---

## 2) API Gateway returned 503 to Users service

### Symptom

- Requests through API Gateway to Users endpoint hung for a while, then returned 503

### Root cause

Port mismatch in Users manifests:

- App was listening on `8080`
- Kubernetes Service for users was configured to `9090`

So API Gateway traffic was routed to a non-listening downstream port.

### What I changed

Updated Users manifests to 8080:

- `aks/users-microservice-deployment.yaml`
- `aks/users-microservice.service.yaml`

### Verify service wiring

```bash
kubectl get svc -n commercefabric-namespace users-microservice -o wide
kubectl get endpoints -n commercefabric-namespace users-microservice -o wide
kubectl logs -n commercefabric-namespace deployment/users-microservice-deployment --tail=50
```

What you should see:

- Service port is `8080`
- Endpoints show PodIP with `:8080`
- Users logs show app listening on `8080`

---

## 3) Fast troubleshooting checklist for next time

When a request fails through API Gateway:

1. Check gateway route path
- Look for `UnableToFindDownstreamRouteError` in gateway logs
- This means route path config mismatch (wrong upstream path)

2. Check service + endpoint wiring

```bash
kubectl get svc -n commercefabric-namespace
kubectl get endpoints -n commercefabric-namespace
```

3. Check target pod is actually listening on expected port

```bash
kubectl logs -n commercefabric-namespace deployment/<service-deployment-name> --tail=100
```

4. Check in-cluster connectivity using temporary curl pod

```bash
kubectl run curl-test --rm -i --restart=Never -n commercefabric-namespace --image=curlimages/curl -- sh -c "curl -sS -o /dev/null -w '%{http_code}\n' --max-time 8 http://<service-name>:<port>/"
```

5. If database data looks missing
- Re-run seed Job by deleting and recreating the Job
- Remember: completed Jobs do not re-run on plain `kubectl apply`

---

## 4) Clean reset + re-seed reminder

If you want a fully clean dataset:

1. Delete the seed Job
2. Replace database Pod
3. Re-apply seed ConfigMap
4. Recreate seed Job
5. Verify counts

Detailed per-database commands are in:

- `docs/DatabaseSeedingAndPersistence.md`

---

## 5) Persistence reminder (important)

Current setup uses no PVC for MySQL/PostgreSQL/MongoDB data.

That means:

- Data can be lost when Pods are replaced (for example during image updates)
- Seed Jobs may need to be re-run after Pod replacement

If you need real persistence across restarts and upgrades, add a PersistentVolumeClaim and mount data directories in each database deployment.
