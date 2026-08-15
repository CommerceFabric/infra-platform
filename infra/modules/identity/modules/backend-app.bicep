extension microsoftGraphV1

@description('Backend application redirect URI')
param redirectUri string

@description('Stable ID for the backend-scope OAuth permission')
param backendScopeId string

// Microsoft Graph application ID
var microsoftGraphAppId = '00000003-0000-0000-c000-000000000000'

// Microsoft Graph delegated permission
var userReadScopeId = 'e1fe6dd8-ba31-4d61-89e7-88639da4683d'

// Microsoft Graph application permissions
var directoryReadWriteAllRoleId = '19dbc75e-c2e2-444c-a770-ec69d8559fc7'
var userReadWriteAllRoleId = '741f803b-c850-494e-b5df-cde7c675a1ca'

resource backendApp 'Microsoft.Graph/applications@v1.0' = {
  uniqueName: 'commercefabric-backend'
  displayName: 'CommerceFabric Backend'

  signInAudience: 'AzureADMyOrg'

  identifierUris: [
    'api://CommerceFabric-Backend'
  ]

  isFallbackPublicClient: true

  api: {
    requestedAccessTokenVersion: 2

    oauth2PermissionScopes: [
      {
        id: backendScopeId
        value: 'backend-scope'
        type: 'Admin'
        isEnabled: true
        adminConsentDisplayName: 'backend-scope'
        adminConsentDescription: 'backend-scope'
        userConsentDisplayName: null
        userConsentDescription: null
      }
    ]
  }

  web: {
    redirectUris: [
      redirectUri
    ]

    implicitGrantSettings: {
      enableAccessTokenIssuance: false
      enableIdTokenIssuance: false
    }
  }

  requiredResourceAccess: [
    {
      resourceAppId: microsoftGraphAppId

      resourceAccess: [
        {
          id: userReadScopeId
          type: 'Scope'
        }
        {
          id: directoryReadWriteAllRoleId
          type: 'Role'
        }
        {
          id: userReadWriteAllRoleId
          type: 'Role'
        }
      ]
    }
  ]
}

resource backendServicePrincipal 'Microsoft.Graph/servicePrincipals@v1.0' = {
  appId: backendApp.appId

  accountEnabled: true
  appRoleAssignmentRequired: false

  tags: [
    'HideApp'
    'WindowsAzureActiveDirectoryIntegratedApp'
  ]
}

output applicationObjectId string = backendApp.id
output clientId string = backendApp.appId

output servicePrincipalObjectId string = backendServicePrincipal.id

output identifierUri string = 'api://CommerceFabric-Backend'

output scopeId string = backendScopeId
output scopeValue string = 'backend-scope'
output scope string = 'api://CommerceFabric-Backend/backend-scope'
