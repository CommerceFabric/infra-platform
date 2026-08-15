extension microsoftGraphV1

@description('SPA redirect URI')
param spaRedirectUri string = 'https://localhost:4200/'

@description('SPA logout URI')
param logoutUri string = 'https://localhost:4200/'

@description('Stable ID for the access_as_user scope')
param accessAsUserScopeId string

// Microsoft Graph
var microsoftGraphAppId = '00000003-0000-0000-c000-000000000000'

// Microsoft Graph delegated User.Read
var userReadScopeId = 'e1fe6dd8-ba31-4d61-89e7-88639da4683d'

resource frontendApp 'Microsoft.Graph/applications@v1.0' = {
  uniqueName: 'commercefabric-frontend'
  displayName: 'CommerceFabric FrontEnd'

  signInAudience: 'AzureADMyOrg'

  identifierUris: [
    'api://commercefabric'
  ]

  isFallbackPublicClient: true

  api: {
    requestedAccessTokenVersion: 2

    oauth2PermissionScopes: [
      {
        id: accessAsUserScopeId
        value: 'access_as_user'
        type: 'Admin'
        isEnabled: true
        adminConsentDisplayName: 'access_as_user'
        adminConsentDescription: 'access_as_user'
        userConsentDisplayName: null
        userConsentDescription: null
      }
    ]
  }

  spa: {
    redirectUris: [
      spaRedirectUri
    ]
  }

  web: {
    logoutUrl: logoutUri

    redirectUris: []

    implicitGrantSettings: {
      enableAccessTokenIssuance: true
      enableIdTokenIssuance: true
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
      ]
    }
  ]
}

resource frontendServicePrincipal 'Microsoft.Graph/servicePrincipals@v1.0' = {
  appId: frontendApp.appId

  accountEnabled: true
  appRoleAssignmentRequired: false

  tags: [
    'HideApp'
    'WindowsAzureActiveDirectoryIntegratedApp'
  ]
}

output applicationObjectId string = frontendApp.id
output clientId string = frontendApp.appId

output servicePrincipalObjectId string = frontendServicePrincipal.id

output identifierUri string = 'api://commercefabric'
output scopeId string = accessAsUserScopeId
output scopeValue string = 'access_as_user'
output scope string = 'api://commercefabric/access_as_user'
