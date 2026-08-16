@description('APIM gateway URL used as the Backend app redirect URI')
param apimGatewayUrl string = 'https://commercefabricapimanagement.azure-api.net/'

@description('CommerceFabric FrontEnd SPA redirect URI')
param frontendRedirectUri string = 'https://localhost:4200/'

@description('CommerceFabric FrontEnd logout URI')
param frontendLogoutUri string = 'https://localhost:4200/'

// Preserve the existing application-defined scope IDs.
var frontendScopeId = 'f0588a86-a785-4d85-b50b-b0941babb55c'
var backendScopeId = 'd815a5f1-6009-4c05-8251-d3c4882c98a4'

module frontend './modules/frontend-app.bicep' = {
  name: 'commercefabric-frontend-identity'
  params: {
    spaRedirectUri: frontendRedirectUri
    logoutUri: frontendLogoutUri
    accessAsUserScopeId: frontendScopeId
  }
}

module backend './modules/backend-app.bicep' = {
  name: 'commercefabric-backend-identity'
  params: {
    redirectUri: apimGatewayUrl
    backendScopeId: backendScopeId
  }
}


// ============================================================
// Disaster recovery outputs
// ============================================================

output AZURE_ENTRA_FRONTEND_CLIENT_ID string = frontend.outputs.clientId

output AZURE_ENTRA_FRONTEND_OBJECT_ID string = frontend.outputs.applicationObjectId

output AZURE_ENTRA_FRONTEND_SCOPE string = frontend.outputs.scope

output AZURE_ENTRA_BACKEND_CLIENT_ID string = backend.outputs.clientId

output AZURE_ENTRA_BACKEND_OBJECT_ID string = backend.outputs.applicationObjectId

output AZURE_ENTRA_BACKEND_SERVICE_PRINCIPAL_ID string = backend.outputs.servicePrincipalObjectId

output AZURE_ENTRA_BACKEND_SCOPE string = backend.outputs.scope

// APIM should validate tokens intended for the FrontEnd/API app.
output APIM_JWT_AUDIENCE string = frontend.outputs.clientId
