targetScope = 'resourceGroup'

@description('AKS cluster name')
param aksClusterName string

@description('Azure Container Registry name')
param acrName string

@description('Object/principal ID of the GitHub Actions service principal')
param githubDeploymentPrincipalId string


// ============================================================
// Existing resources
//
// This file is intentionally deployed AFTER main.bicep.
// ============================================================

resource acr 'Microsoft.ContainerRegistry/registries@2025-11-01' existing = {
  name: acrName
}

resource aks 'Microsoft.ContainerService/managedClusters@2026-01-01' existing = {
  name: aksClusterName
}


// ============================================================
// Built-in Azure role definitions
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
// AKS kubelet -> ACR AcrPull
// ============================================================

resource aksAcrPull 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(
    acr.id,
    aksClusterName,
    acrPullRoleDefinitionId
  )

  scope: acr

  properties: {
    roleDefinitionId: acrPullRoleDefinitionId
    principalId: aks.properties.identityProfile.kubeletidentity.objectId
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
    aks.id,
    githubDeploymentPrincipalId,
    aksClusterUserRoleDefinitionId
  )

  scope: aks

  properties: {
    roleDefinitionId: aksClusterUserRoleDefinitionId
    principalId: githubDeploymentPrincipalId
    principalType: 'ServicePrincipal'
  }
}
