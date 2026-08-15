@description('Name of the Azure Service Bus namespace')
param namespaceName string

@description('Azure region')
param location string = resourceGroup().location

@description('Tags applied to the Service Bus namespace')
param tags object = {}

resource serviceBusNamespace 'Microsoft.ServiceBus/namespaces@2026-01-01' = {
  name: namespaceName
  location: location

  sku: {
    name: 'Standard'
    tier: 'Standard'
  }

  properties: {
    disableLocalAuth: false
    minimumTlsVersion: '1.2'
    publicNetworkAccess: 'Enabled'
  }

  tags: tags
}

resource rootAuthorizationRule 'Microsoft.ServiceBus/namespaces/authorizationRules@2026-01-01' = {
  parent: serviceBusNamespace
  name: 'RootManageSharedAccessKey'

  properties: {
    rights: [
      'Listen'
      'Manage'
      'Send'
    ]
  }
}


// ============================================================
// Topics
// ============================================================

resource ordersCreatedTopic 'Microsoft.ServiceBus/namespaces/topics@2026-01-01' = {
  parent: serviceBusNamespace
  name: 'orders.created'

  properties: {
    defaultMessageTimeToLive: 'PT6H'
    duplicateDetectionHistoryTimeWindow: 'PT10M'
    enableBatchedOperations: true
    enableExpress: false
    enablePartitioning: false
    maxMessageSizeInKilobytes: 256
    maxSizeInMegabytes: 1024
    requiresDuplicateDetection: false
    status: 'Active'
    supportOrdering: false
  }
}

resource productsDeletesTopic 'Microsoft.ServiceBus/namespaces/topics@2026-01-01' = {
  parent: serviceBusNamespace
  name: 'products.deletes'

  properties: {
    defaultMessageTimeToLive: 'PT6H'
    duplicateDetectionHistoryTimeWindow: 'PT10M'
    enableBatchedOperations: true
    enableExpress: false
    enablePartitioning: false
    maxMessageSizeInKilobytes: 256
    maxSizeInMegabytes: 1024
    requiresDuplicateDetection: false
    status: 'Active'
    supportOrdering: false
  }
}

resource productsUpdatesTopic 'Microsoft.ServiceBus/namespaces/topics@2026-01-01' = {
  parent: serviceBusNamespace
  name: 'products.updates'

  properties: {
    defaultMessageTimeToLive: 'PT1H'
    duplicateDetectionHistoryTimeWindow: 'PT10M'
    enableBatchedOperations: true
    enableExpress: false
    enablePartitioning: false
    maxMessageSizeInKilobytes: 256
    maxSizeInMegabytes: 1024
    requiresDuplicateDetection: false
    status: 'Active'
    supportOrdering: true
  }
}


// ============================================================
// orders.created subscriptions
// ============================================================

resource ordersCreatedProductsSubscription 'Microsoft.ServiceBus/namespaces/topics/subscriptions@2026-01-01' = {
  parent: ordersCreatedTopic
  name: 'orders.created.products'

  properties: {
    deadLetteringOnFilterEvaluationExceptions: false
    deadLetteringOnMessageExpiration: false
    defaultMessageTimeToLive: 'P14D'
    enableBatchedOperations: true
    lockDuration: 'PT1M'
    maxDeliveryCount: 10
    requiresSession: false
    status: 'Active'
  }
}

resource ordersCreatedProductsDefaultRule 'Microsoft.ServiceBus/namespaces/topics/subscriptions/rules@2026-01-01' = {
  parent: ordersCreatedProductsSubscription
  name: '\$Default'

  properties: {
    filterType: 'SqlFilter'

    sqlFilter: {
      compatibilityLevel: 20
      sqlExpression: '1=1'
    }
  }
}


// ============================================================
// products.updates subscriptions
// ============================================================

resource productsUpdatesOrdersSubscription 'Microsoft.ServiceBus/namespaces/topics/subscriptions@2026-01-01' = {
  parent: productsUpdatesTopic
  name: 'products.updates.orders'

  properties: {
    deadLetteringOnFilterEvaluationExceptions: true
    deadLetteringOnMessageExpiration: false
    enableBatchedOperations: true
    lockDuration: 'PT1M'
    maxDeliveryCount: 10
    requiresSession: false
    status: 'Active'
  }
}

resource productsUpdatesOrdersDefaultRule 'Microsoft.ServiceBus/namespaces/topics/subscriptions/rules@2026-01-01' = {
  parent: productsUpdatesOrdersSubscription
  name: '\$Default'

  properties: {
    filterType: 'SqlFilter'

    sqlFilter: {
      compatibilityLevel: 20
      sqlExpression: '1=1'
    }
  }
}


// ============================================================
// Outputs
// ============================================================

output namespaceName string = serviceBusNamespace.name

output namespaceId string = serviceBusNamespace.id

output fullyQualifiedNamespace string = '${serviceBusNamespace.name}.servicebus.windows.net'

output ordersCreatedTopicName string = ordersCreatedTopic.name
output productsDeletesTopicName string = productsDeletesTopic.name
output productsUpdatesTopicName string = productsUpdatesTopic.name

output ordersCreatedProductsSubscriptionName string = ordersCreatedProductsSubscription.name
output productsUpdatesOrdersSubscriptionName string = productsUpdatesOrdersSubscription.name

@secure()
output connectionString string = rootAuthorizationRule.listKeys().primaryConnectionString
