@description('Name of the API Management service')
param apimName string

@description('Azure region')
param location string = 'ukwest'

@description('Publisher email address')
param publisherEmail string

@description('Tags applied to APIM')
param tags object = {}

resource apim 'Microsoft.ApiManagement/service@2024-05-01' = {
  name: apimName
  location: location
  tags: tags

  sku: {
    name: 'Consumption'
    capacity: 0
  }

  properties: {
    publisherEmail: publisherEmail
    publisherName: 'CommerceFabric'
    publicNetworkAccess: 'Enabled'
    virtualNetworkType: 'None'

    customProperties: {
      'Microsoft.WindowsAzure.ApiManagement.Gateway.Protocols.Server.Http2': 'False'
      'Microsoft.WindowsAzure.ApiManagement.Gateway.Security.Backend.Protocols.Ssl30': 'False'
      'Microsoft.WindowsAzure.ApiManagement.Gateway.Security.Backend.Protocols.Tls10': 'False'
      'Microsoft.WindowsAzure.ApiManagement.Gateway.Security.Backend.Protocols.Tls11': 'False'
      'Microsoft.WindowsAzure.ApiManagement.Gateway.Security.Protocols.Tls10': 'False'
      'Microsoft.WindowsAzure.ApiManagement.Gateway.Security.Protocols.Tls11': 'False'
    }
  }
}

output apimName string = apim.name
output gatewayUrl string = apim.properties.gatewayUrl
