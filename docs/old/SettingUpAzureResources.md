
# Azure Infrastructure Setup

**Subscription:** `CommerceFabric_Subscription`
**Resource Group:** `CommerceFabric-ResourceGroup`
**Region:** `UK South`
**Container Registry:** `commercefabricregistry`
**AKS Cluster:** `CommerceFabric-aks-cluster`
**AKS VM:** `Standard_D2lds_v6`
**Nodes:** `1`

## IMPORTANT Cost Control

> ⚠️ **IMPORTANT**
>
> **The AKS cluster must be stopped whenever it is not being used.**
>
> A running AKS cluster incurs compute charges continuously. With a limited monthly budget, leaving the cluster running unnecessarily can result in unexpected costs.
>
> **START → USE → STOP**
>
> Stopping AKS prevents the normal compute charges for the stopped nodes. Other Azure resources, such as the Container Registry or storage, may still incur charges.

---

## 1. Select the Subscription

```powershell
az account set --subscription "CommerceFabric_Subscription"
```

Verify:

```powershell
az account show --query "{Name:name, SubscriptionId:id, State:state}" --output table
```

---

## 2. Create the Resource Group

```powershell
az group create `
  --name CommerceFabric-ResourceGroup `
  --location uksouth
```

---

## 3. Create the Container Registry

```powershell
az acr create `
  --resource-group CommerceFabric-ResourceGroup `
  --name commercefabricregistry `
  --sku Basic
```

---

## 4. Register Required Resource Providers

```powershell
az provider register --namespace Microsoft.ContainerRegistry --wait
az provider register --namespace Microsoft.Insights --wait
az provider register --namespace Microsoft.OperationalInsights --wait
az provider register --namespace Microsoft.ContainerService --wait
az provider register --namespace Microsoft.Network --wait
az provider register --namespace Microsoft.Compute --wait
az provider register --namespace Microsoft.OperationsManagement --wait
az provider register --namespace Microsoft.Authorization --wait
az provider register --namespace Microsoft.Storage --wait
```

These only need to be registered once.

---

## 5. Create the AKS Cluster

```powershell
az aks create `
  --resource-group CommerceFabric-ResourceGroup `
  --name CommerceFabric-aks-cluster `
  --location uksouth `
  --node-count 1 `
  --node-vm-size Standard_D2lds_v6 `
  --generate-ssh-keys
```

### Optional Monitoring

If monitoring is required, add:

```text
--enable-addons monitoring
```

Monitoring can generate additional costs, so only enable it when required.

---

## 6. Connect to the AKS Cluster

Retrieve the AKS credentials:

```powershell
az aks get-credentials `
  --resource-group CommerceFabric-ResourceGroup `
  --name CommerceFabric-aks-cluster
```

This updates your local Kubernetes configuration and allows `kubectl` to communicate with the AKS cluster.

### Get Cluster Information

```powershell
kubectl cluster-info
```

### View `kubectl` Help

```powershell
kubectl --help
```

### Check the Current Cluster

```powershell
kubectl config current-context
```

This should show:

```text
CommerceFabric-aks-cluster
```

---

# AKS Cost Management

## Start When Required

```powershell
az aks start `
  --resource-group CommerceFabric-ResourceGroup `
  --name CommerceFabric-aks-cluster
```

## Stop When Finished

```powershell
az aks stop `
  --resource-group CommerceFabric-ResourceGroup `
  --name CommerceFabric-aks-cluster
```

## Check Whether AKS Is Stopped

```powershell
az aks show `
  --resource-group CommerceFabric-ResourceGroup `
  --name CommerceFabric-aks-cluster `
  --query "powerState.code" `
  --output tsv
```

Expected:

```text
Stopped
```

> **Daily rule: START → USE → STOP**
>
> Do **not** leave AKS running when it is not required.
>
> The cluster does **not** need to be deleted and recreated. It can be started and stopped as required, preserving the existing configuration.
