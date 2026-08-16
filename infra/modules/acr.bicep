@description('Name of the Azure Container Registry')
param registryName string

@description('Azure region for the registry')
param location string = 'ukwest'

@description('Tags applied to the registry')
param tags object = {}

resource registry 'Microsoft.ContainerRegistry/registries@2025-11-01' = {
  name: registryName
  location: location

  sku: {
    name: 'Basic'
  }

  properties: {
    adminUserEnabled: true
    anonymousPullEnabled: false
    publicNetworkAccess: 'Enabled'
    dataEndpointEnabled: false
    networkRuleBypassOptions: 'AzureServices'
  }

  tags: tags
}

output registryName string = registry.name

output registryId string = registry.id

output loginServer string = registry.properties.loginServer
