# Database Seeding and Persistence on AKS

## Overview

This document describes the database seeding and persistence strategy for **MySQL, PostgreSQL, and MongoDB** running on Azure Kubernetes Service (AKS).

It covers:

* Database seeding architecture and implementation.
* Data persistence behavior during Pod replacement and image upgrades.
* Clean database reset and re-seeding procedures.
* Required changes to support persistent database storage.

---

## Current Architecture

Each database follows the same Kubernetes pattern:

1. A **Deployment** runs the database container.
2. A **Service** provides internal DNS-based access.
3. A **ConfigMap** contains the database seed script.
4. A **Job** waits for the database to become available and executes the seed script.

### Current Kubernetes Resources

| Database   | Deployment                     | Service                     | Seed ConfigMap                     | Seed Job                     |
| ---------- | ------------------------------ | --------------------------- | ---------------------------------- | ---------------------------- |
| MySQL      | `aks/mysql-deployment.yaml`    | `aks/mysql.service.yaml`    | `aks/mysql-seed-configmap.yaml`    | `aks/mysql-seed-job.yaml`    |
| PostgreSQL | `aks/postgres-deployment.yaml` | `aks/postgres.service.yaml` | `aks/postgres-seed-configmap.yaml` | `aks/postgres-seed-job.yaml` |
| MongoDB    | `aks/mongodb-deployment.yaml`  | `aks/mongodb.service.yaml`  | `aks/mongodb-seed-configmap.yaml`  | `aks/mongodb-seed-job.yaml`  |

---

# Data Persistence

## Current State

**MySQL, PostgreSQL, and MongoDB currently use the Pod's writable container filesystem for database storage.**

No PersistentVolumeClaim (PVC) is currently mounted for the database data directories.

As a result:

* Data persists only for the lifetime of the current Pod.
* Restarting or replacing the Pod can result in complete data loss.
* Updating the database image can trigger Pod replacement and therefore data loss.
* Seed Jobs must be executed again after data loss to restore application data.

This configuration should therefore be considered **ephemeral and non-production-safe for persistent database workloads**.

---

## MySQL

### Seeding Flow

The MySQL deployment consists of:

* MySQL Deployment
* MySQL Service (`mysql`)
* Seed ConfigMap
* Seed Job

The Seed Job waits for MySQL to become available before executing the SQL contained in the ConfigMap.

### Persistence Behaviour

The MySQL data directory `/var/lib/mysql` is not backed by persistent storage.

During a Pod replacement:

```text
Pod replaced
    ↓
Container filesystem removed
    ↓
/var/lib/mysql lost
    ↓
MySQL database recreated
    ↓
Seed Job required to restore application data
```

The database `productDB` may be recreated automatically through `MYSQL_DATABASE`, but application tables and data depend on the seed process.

### Re-seeding

Completed Kubernetes Jobs do not automatically execute again when `kubectl apply` is run. The existing Job must be deleted before it can be recreated.

### Clean Reset

```bash
kubectl delete job mysql-seed-job  -n commercefabric-namespace  --ignore-not-found

kubectl delete pod  -n commercefabric-namespace  -l app=mysql

kubectl rollout status deployment/mysql-deployment  -n commercefabric-namespace

kubectl apply -f aks/mysql-seed-configmap.yaml
kubectl apply -f aks/mysql-seed-job.yaml

kubectl wait  --for=condition=complete  job/mysql-seed-job  -n commercefabric-namespace  --timeout=120s
```

### Verification

```bash
kubectl exec  -n commercefabric-namespace  deployment/mysql-deployment  -- mysql -uroot -padmin  -e "SHOW TABLES IN productDB; SELECT COUNT(*) AS ProductCount FROM productDB.Products;"
```

Expected result:

* `Products` table exists.
* Current seed contains **12 products**.

---

# PostgreSQL

### Seeding Flow

The PostgreSQL deployment consists of:

* PostgreSQL Deployment
* PostgreSQL Service (`postgres`)
* Seed ConfigMap
* Seed Job

The Seed Job waits for PostgreSQL to become available before executing the SQL contained in the ConfigMap.

### Persistence Behaviour

PostgreSQL data is not backed by a PersistentVolumeClaim.

Pod replacement therefore removes the database files and requires the seed Job to restore application data.

The `commercefabricUsers` database is recreated through `POSTGRES_DB`, while the application tables and data are restored through the seed process.

### Re-seeding Consideration

The current PostgreSQL seed uses standard `INSERT` statements without `ON CONFLICT` handling.

Consequently, running the seed against existing data can result in duplicate-key errors.

A clean reset is therefore recommended before re-seeding.

### Clean Reset

```bash
kubectl delete job postgres-seed-job  -n commercefabric-namespace  --ignore-not-found

kubectl delete pod  -n commercefabric-namespace  -l app=postgres

kubectl rollout status deployment/postgres-deployment  -n commercefabric-namespace

kubectl apply -f aks/postgres-seed-configmap.yaml
kubectl apply -f aks/postgres-seed-job.yaml

kubectl wait  --for=condition=complete  job/postgres-seed-job  -n commercefabric-namespace  --timeout=120s
```

### Verification

```bash
kubectl exec  -n commercefabric-namespace  deployment/postgres-deployment  -- psql  -U postgres  -d commercefabricUsers  -c "SELECT COUNT(*) AS user_count FROM public.users;"
```

---

# MongoDB

### Seeding Flow

The MongoDB deployment consists of:

* MongoDB Deployment
* MongoDB Service (`mongodb`)
* Seed ConfigMap
* Seed Job

The Seed Job waits for MongoDB to become available before executing the JavaScript seed script.

### Persistence Behaviour

MongoDB data is not backed by a PersistentVolumeClaim.

Pod replacement therefore removes the database files and requires the seed Job to restore application data.

The `OrdersDb` database and `orders` collection data are restored through the seed process.

### Clean Reset

```bash
kubectl delete job mongodb-seed-job  -n commercefabric-namespace  --ignore-not-found

kubectl delete pod  -n commercefabric-namespace  -l app=mongodb

kubectl rollout status deployment/mongodb-deployment  -n commercefabric-namespace

kubectl apply -f aks/mongodb-seed-configmap.yaml
kubectl apply -f aks/mongodb-seed-job.yaml

kubectl wait  --for=condition=complete  job/mongodb-seed-job  -n commercefabric-namespace  --timeout=120s
```

### Verification

```bash
kubectl exec  -n commercefabric-namespace  deployment/mongodb-deployment  -- mongosh --quiet  --eval "db.getSiblingDB('OrdersDb').orders.countDocuments()"
```

---

# Persistent Storage — Required Improvement

To support reliable database operation across Pod restarts, replacements, and image upgrades, each database should use Kubernetes persistent storage.

### Required Changes

For each database:

1. Create a **PersistentVolumeClaim**.
2. Mount the PVC to the database's data directory.
3. Ensure the database uses the mounted volume for all persistent data.
4. Keep seed scripts idempotent where possible.
5. Use Seed Jobs primarily for initial database bootstrap or controlled data refreshes.

### Recommended Mounts

| Database   | Data Directory            |
| ---------- | ------------------------- |
| MySQL      | `/var/lib/mysql`          |
| PostgreSQL | PostgreSQL data directory |
| MongoDB    | `/data/db`                |

With persistent storage, the lifecycle becomes:

```text
Pod replaced
    ↓
New Pod starts
    ↓
Existing PVC mounted
    ↓
Existing database files available
    ↓
Application data preserved
```

The database image can then be upgraded without treating Pod replacement as a destructive operation.

---

# Summary

| Database   | Current Storage      | Pod Replacement | Seed Required After Data Loss | Persistent Storage |
| ---------- | -------------------- | --------------- | ----------------------------- | ------------------ |
| MySQL      | Container filesystem | Data lost       | Yes                           | Required           |
| PostgreSQL | Container filesystem | Data lost       | Yes                           | Required           |
| MongoDB    | Container filesystem | Data lost       | Yes                           | Required           |

**Current status:** Database storage is ephemeral.

**Target state:** All database data should be backed by PersistentVolumeClaims so that Pod replacement, restarts, and database image upgrades do not result in data loss.
