# Database Seeding and Persistence on AKS

## Overview

This document explains how database seeding works for the CommerceFabric platform and how data behaves when running databases on Azure Kubernetes Service (AKS).

The platform currently uses:

- MySQL
- PostgreSQL
- MongoDB

Each database uses:

- A Kubernetes Deployment to run the database
- A Kubernetes Service for internal communication
- A ConfigMap containing seed data
- A Kubernetes Job to run the seed process

---

# Current Database Setup

| Database | Deployment | Seed Job |
|---|---|---|
| MySQL | `mysql-deployment` | `mysql-seed-job` |
| PostgreSQL | `postgres-deployment` | `postgres-seed-job` |
| MongoDB | `mongodb-deployment` | `mongodb-seed-job` |

The seed Jobs wait for the database to start, then populate the required application data.

---

# Database Persistence

## Current State

The databases currently store data inside the container filesystem.

No PersistentVolumeClaims (PVCs) are currently configured.

This means:

- Data survives while the Pod remains running.
- Replacing or recreating a Pod deletes the database files.
- Database image upgrades can result in data loss.
- Seed Jobs must be run again after data is lost.

Current setup:

```

Pod replaced
|
v
Container filesystem removed
|
v
Database data lost
|
v
Seed Job required
|
v
Database restored

````

This is suitable for development and testing but is **not recommended for production workloads**.

---

# Reset and Re-seed Databases

Because Kubernetes Jobs only run once, existing seed Jobs must be removed before they can run again.

## MySQL

```bash
kubectl delete job mysql-seed-job -n commercefabric-namespace --ignore-not-found

kubectl delete pod -n commercefabric-namespace -l app=mysql

kubectl rollout status deployment/mysql-deployment -n commercefabric-namespace

kubectl apply -R -f aks/mysql-seed-job.yaml
````

Verify:

```bash
kubectl exec -n commercefabric-namespace deployment/mysql-deployment -- \
mysql -uroot -padmin -e "SELECT COUNT(*) FROM productDB.Products;"
```

---

## PostgreSQL

```bash
kubectl delete job postgres-seed-job -n commercefabric-namespace --ignore-not-found

kubectl delete pod -n commercefabric-namespace -l app=postgres

kubectl rollout status deployment/postgres-deployment -n commercefabric-namespace

kubectl apply -R -f aks/postgres-seed-job.yaml
```

Verify:

```bash
kubectl exec -n commercefabric-namespace deployment/postgres-deployment -- \
psql -U postgres -d commercefabricUsers -c "SELECT COUNT(*) FROM users;"
```

---

## MongoDB

```bash
kubectl delete job mongodb-seed-job -n commercefabric-namespace --ignore-not-found

kubectl delete pod -n commercefabric-namespace -l app=mongodb

kubectl rollout status deployment/mongodb-deployment -n commercefabric-namespace

kubectl apply -R -f aks/mongodb-seed-job.yaml
```

Verify:

```bash
kubectl exec -n commercefabric-namespace deployment/mongodb-deployment -- \
mongosh --quiet --eval "db.getSiblingDB('OrdersDb').orders.countDocuments()"
```

---

# Recommended Improvement: Persistent Storage

For production use, each database should use Kubernetes persistent storage.

Required changes:

1. Create a PersistentVolumeClaim (PVC).
2. Mount the PVC into the database container.
3. Store database files on the mounted volume.
4. Make seed scripts safe to run multiple times where possible.

Recommended database storage locations:

| Database   | Storage Path              |
| ---------- | ------------------------- |
| MySQL      | `/var/lib/mysql`          |
| PostgreSQL | PostgreSQL data directory |
| MongoDB    | `/data/db`                |

With persistent storage:

```
Pod replaced
      |
      v
New Pod starts
      |
      v
Existing PVC mounted
      |
      v
Database data restored
      |
      v
Application continues running
```

---

# Summary

| Database   | Current Storage      | Data Survives Pod Replacement? |
| ---------- | -------------------- | ------------------------------ |
| MySQL      | Container filesystem | ❌ No                           |
| PostgreSQL | Container filesystem | ❌ No                           |
| MongoDB    | Container filesystem | ❌ No                           |

Current status:

> Database storage is temporary and intended for development/testing.

Recommended future state:

> Use PersistentVolumeClaims for all databases so that Pod restarts, deployments, and image upgrades do not cause data loss.