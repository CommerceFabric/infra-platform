targetScope = 'resourceGroup'


@description('Azure deployment region. Use an Azure region name such as "uksouth". You can list valid regions with: az account list-locations --query "[].name" -o tsv')
param location string = 'uksouth'


@description('Prefix used when naming CommerceFabric Azure resources. Choose a short, lowercase project/environment name such as "commercefabric" or "commercefabric-test".')
param projectName string = 'commercefabric'


@description('AKS cluster name. Choose a unique name within the target resource group, for example "commercefabric-aks-cluster". You can see existing AKS cluster names with: az aks list --query "[].name" -o tsv')
param aksClusterName string = '${projectName}-aks-cluster'


@description('AKS DNS prefix used to generate the managed cluster DNS name. Choose a short DNS-safe value such as "commercefabric". For a new cluster this can be chosen freely; it cannot normally be changed after the AKS cluster has been created.')
param aksDnsPrefix string = projectName


@description('Azure Service Bus namespace name. This must be globally unique across Azure. Choose a DNS-safe name such as "commercefabric-servicebus-namespace". Existing namespaces can be listed with: az servicebus namespace list --query "[].name" -o tsv')
param serviceBusNamespaceName string = '${projectName}-servicebus-namespace'


@description('Azure Container Registry name. This must be globally unique, contain only lowercase letters and numbers, and be 5-50 characters long. Example: "commercefabricregistry". Check availability with: az acr check-name --name <NAME>')
param acrName string = 'commercefabricregistry'


@description('Azure API Management service name. This name forms the public hostname https://<name>.azure-api.net and must be globally unique. Example: "commercefabricapimanagement". Existing APIM services can be listed with: az apim list --query "[].name" -o tsv')
param apimName string = 'commercefabricapimanagement'


@description('Microsoft Entra service principal OBJECT ID used by GitHub Actions for Azure OIDC deployments and RBAC assignments. This is NOT the application/client ID. Find it with: az ad sp show --id <AZURE_CLIENT_ID> --query id -o tsv')
param githubDeploymentPrincipalId string


@description('SSH PUBLIC key used for the AKS Linux node administrator account. Use the contents of a .pub file only; never provide the private key. Generate one with: ssh-keygen -t ed25519 -f "$HOME\\.ssh\\commercefabric-aks" -C "commercefabric-aks". Then read it with: Get-Content "$HOME\\.ssh\\commercefabric-aks.pub"')
param aksSshPublicKey string

// ============================================================
// Common configuration
// ============================================================

var commonTags = {
  project: 'CommerceFabric'
  managedBy: 'Bicep'
  repository: 'infra-platform'
}


// ============================================================
// Service Bus
// ============================================================

module serviceBus './modules/servicebus.bicep' = {
  name: 'commercefabric-servicebus'
  params: {
    namespaceName: serviceBusNamespaceName
    location: location
    tags: commonTags
  }
}


// ============================================================
// Azure Container Registry
// ============================================================

module registry './modules/acr.bicep' = {
  name: 'commercefabric-acr'
  params: {
    registryName: acrName
    location: 'ukwest'
    tags: commonTags
  }
}


// ============================================================
// Azure Kubernetes Service
// ============================================================

module aks './modules/aks.bicep' = {
  name: 'commercefabric-aks'
  params: {
    clusterName: aksClusterName
    location: location
    dnsPrefix: aksDnsPrefix
    sshPublicKey: aksSshPublicKey
    tags: commonTags
  }
}


// ============================================================
// API Management
// ============================================================

module apim './modules/apim.bicep' = {
  name: 'commercefabric-apim'
  params: {
    apimName: apimName
    location: 'ukwest'
    publisherEmail: 'danielmusselwhite@outlook.com'
    tags: commonTags
  }
}

// ============================================================
// Built-in Azure role IDs
// ============================================================

var acrPullRoleDefinitionId = subscriptionResourceId(
  'Microsoft.Authorization/roleDefinitions',
  '7f951dda-4ed3-4680-a7ca-43fe172d538d'
)

var acrPushRoleDefinitionId = subscriptionResourceId(
  'Microsoft.Authorization/roleDefinitions',
  '8311e382-0749-4cb8-b61a-304f252e45ec'
)

var aksClusterUserRoleDefinitionId = subscriptionResourceId(
  'Microsoft.Authorization/roleDefinitions',
  '4abbcc35-e782-43d8-92c5-2d3f1bd2253f'
)

// ============================================================
// Outputs
// ============================================================

output AZURE_RESOURCE_GROUP string = resourceGroup().name

output AZURE_AKS_CLUSTER string = aksClusterName

output ACR_NAME string = acrName

output ACR_LOGIN_SERVER string = registry.outputs.loginServer

output AZURE_SERVICEBUS_NAMESPACE string = serviceBusNamespaceName

output AZURE_SERVICEBUS_FQDN string = serviceBus.outputs.fullyQualifiedNamespace

output ordersCreatedTopic string = serviceBus.outputs.ordersCreatedTopicName

output productsDeletesTopic string = serviceBus.outputs.productsDeletesTopicName

output productsUpdatesTopic string = serviceBus.outputs.productsUpdatesTopicName

output ordersCreatedProductsSubscription string = serviceBus.outputs.ordersCreatedProductsSubscriptionName

output productsUpdatesOrdersSubscription string = serviceBus.outputs.productsUpdatesOrdersSubscriptionName

@secure()
output AZURE_SERVICEBUS_CONNECTION string = serviceBus.outputs.connectionString

output APIM_NAME string = apim.outputs.apimName

output APIM_GATEWAY_URL string = apim.outputs.gatewayUrl
