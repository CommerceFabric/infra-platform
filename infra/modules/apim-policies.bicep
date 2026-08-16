@description('Name of the existing APIM service')
param apimName string

@description('Allowed browser origin')
param corsOrigin string

@description('OpenID Connect configuration URL')
param openIdConfigurationUrl string

@description('Expected JWT audience')
param apiAudience string

@description('Expected JWT issuer')
param tokenIssuer string


// ============================================================
// Existing APIM
// ============================================================

resource apim 'Microsoft.ApiManagement/service@2024-05-01' existing = {
  name: apimName
}


// ============================================================
// Existing APIs
//
// These are created/imported by configure-apim.ps1 first.
// ============================================================

resource ordersApi 'Microsoft.ApiManagement/service/apis@2024-05-01' existing = {
  parent: apim
  name: 'ordersmicroservice-api'
}

resource productsApi 'Microsoft.ApiManagement/service/apis@2024-05-01' existing = {
  parent: apim
  name: 'commercefabric-productservice-api'
}

resource usersApi 'Microsoft.ApiManagement/service/apis@2024-05-01' existing = {
  parent: apim
  name: 'userservice-api'
}


// ============================================================
// Load and parameterize shared policy
// ============================================================

var rawPolicy = loadTextContent('../apim/api-policy.xml')

var policyWithCors = replace(
  rawPolicy,
  '__CORS_ORIGIN__',
  corsOrigin
)

var policyWithOpenId = replace(
  policyWithCors,
  '__OPENID_CONFIG_URL__',
  openIdConfigurationUrl
)

var policyWithAudience = replace(
  policyWithOpenId,
  '__API_AUDIENCE__',
  apiAudience
)

var finalPolicy = replace(
  policyWithAudience,
  '__TOKEN_ISSUER__',
  tokenIssuer
)


// ============================================================
// Orders policy
// ============================================================

resource ordersPolicy 'Microsoft.ApiManagement/service/apis/policies@2024-05-01' = {
  parent: ordersApi
  name: 'policy'

  properties: {
    format: 'rawxml'
    value: finalPolicy
  }
}


// ============================================================
// Products policy
// ============================================================

resource productsPolicy 'Microsoft.ApiManagement/service/apis/policies@2024-05-01' = {
  parent: productsApi
  name: 'policy'

  properties: {
    format: 'rawxml'
    value: finalPolicy
  }
}


// ============================================================
// Users policy
// ============================================================

resource usersPolicy 'Microsoft.ApiManagement/service/apis/policies@2024-05-01' = {
  parent: usersApi
  name: 'policy'

  properties: {
    format: 'rawxml'
    value: finalPolicy
  }
}
