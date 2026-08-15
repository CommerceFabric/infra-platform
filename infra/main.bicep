targetScope = 'resourceGroup'

@description('Azure deployment region')
param location string = 'uksouth'

@description('Prefix used for CommerceFabric Azure resources')
param projectName string = 'commercefabric'

@description('Object/principal ID of the GitHub Actions service principal')
param githubDeploymentPrincipalId string

@description('SSH public key used by the AKS Linux nodes')
param aksSshPublicKey string


// ============================================================
// Stable resource names
// ============================================================

var serviceBusNamespaceName = '${projectName}-servicebus-namespace'
var acrName = 'commercefabricregistry'
var aksClusterName = '${projectName}-aks-cluster'


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
    dnsPrefix: projectName
    sshPublicKey: aksSshPublicKey
    tags: commonTags
  }
}


// ============================================================
// Resource references used as RBAC scopes
//
// IMPORTANT:
// These names are known before deployment starts.
// Do not use module outputs here.
// ============================================================

resource acr 'Microsoft.ContainerRegistry/registries@2025-11-01' existing = {
  name: acrName
}

resource aksResource 'Microsoft.ContainerService/managedClusters@2026-01-01' existing = {
  name: aksClusterName
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
// AKS -> ACR AcrPull
//
// kubeletObjectId is runtime-generated, so it is fine in
// properties.principalId.
//
// It must NOT be used to generate the role-assignment name.
// ============================================================

resource aksAcrPull 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(
    acr.id,
    aksClusterName,
    'AcrPull'
  )

  scope: acr

  properties: {
    roleDefinitionId: acrPullRoleDefinitionId
    principalId: aks.outputs.kubeletObjectId
    principalType: 'ServicePrincipal'
  }
}


// ============================================================
// GitHub Actions -> ACR AcrPush
// ============================================================

resource githubAcrPush 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(
    acr.id,
    githubDeploymentPrincipalId,
    acrPushRoleDefinitionId
  )

  scope: acr

  properties: {
    roleDefinitionId: acrPushRoleDefinitionId
    principalId: githubDeploymentPrincipalId
    principalType: 'ServicePrincipal'
  }
}


// ============================================================
// GitHub Actions -> AKS Cluster User
// ============================================================

resource githubAksClusterUser 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(
    aksResource.id,
    githubDeploymentPrincipalId,
    aksClusterUserRoleDefinitionId
  )

  scope: aksResource

  properties: {
    roleDefinitionId: aksClusterUserRoleDefinitionId
    principalId: githubDeploymentPrincipalId
    principalType: 'ServicePrincipal'
  }
}


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


// ============================================================
// API Management Service
// ============================================================
// ============================================================
// API Management
// ============================================================

module apim './modules/apim.bicep' = {
  name: 'commercefabric-apim'
  params: {
    apimName: 'commercefabricapimanagement'
    location: 'ukwest'
    publisherEmail: 'danielmusselwhite@outlook.com'
    tags: commonTags
  }
}

output APIM_NAME string = apim.outputs.apimName
output APIM_GATEWAY_URL string = apim.outputs.gatewayUrl
