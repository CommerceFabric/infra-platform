@description('Name of the AKS cluster')
param clusterName string

@description('Azure region')
param location string = 'uksouth'

@description('SSH public key for the Linux node administrator')
param sshPublicKey string

@description('DNS prefix for the AKS cluster')
param dnsPrefix string = 'commercefabric'

@description('Tags applied to the cluster')
param tags object = {}

@description('Kubernetes version')
param kubernetesVersion string = '1.35'

@description('Node VM size')
param nodeVmSize string = 'Standard_D2lds_v6'

@description('Initial node count')
param nodeCount int = 1

resource aks 'Microsoft.ContainerService/managedClusters@2026-01-01' = {
  name: clusterName
  location: location
  tags: tags

  identity: {
    type: 'SystemAssigned'
  }

  sku: {
    name: 'Base'
    tier: 'Free'
  }

  properties: {
    kubernetesVersion: kubernetesVersion
    dnsPrefix: dnsPrefix

    enableRBAC: true
    disableLocalAccounts: false

    oidcIssuerProfile: {
      enabled: true
    }

    linuxProfile: {
      adminUsername: 'azureuser'

      ssh: {
        publicKeys: [
          {
            keyData: sshPublicKey
          }
        ]
      }
    }

    agentPoolProfiles: [
      {
        name: 'nodepool1'
        count: nodeCount
        vmSize: nodeVmSize
        mode: 'System'

        osType: 'Linux'
        osSKU: 'Ubuntu'

        osDiskSizeGB: 128
        osDiskType: 'Managed'

        type: 'VirtualMachineScaleSets'

        maxPods: 250

        enableAutoScaling: false
        enableNodePublicIP: false

        scaleDownMode: 'Delete'

        upgradeSettings: {
          maxSurge: '10%'
          maxUnavailable: '0'
        }
      }
    ]

    networkProfile: {
      networkPlugin: 'azure'
      networkPluginMode: 'overlay'
      networkDataplane: 'azure'

      networkPolicy: 'none'

      loadBalancerSku: 'standard'
      outboundType: 'loadBalancer'

      podCidr: '10.244.0.0/16'
      serviceCidr: '10.0.0.0/16'
      dnsServiceIP: '10.0.0.10'

      ipFamilies: [
        'IPv4'
      ]
    }

    autoUpgradeProfile: {
      nodeOSUpgradeChannel: 'NodeImage'
    }

    metricsProfile: {
      costAnalysis: {
        enabled: false
      }
    }
  }
}


// ============================================================
// Outputs
// ============================================================

output clusterName string = aks.name
output clusterId string = aks.id
output clusterPrincipalId string = aks.identity.principalId

output kubeletObjectId string = aks.properties.identityProfile.kubeletidentity.objectId

output kubeletClientId string = aks.properties.identityProfile.kubeletidentity.clientId

output oidcIssuerUrl string = aks.properties.oidcIssuerProfile.issuerURL

output fqdn string = aks.properties.fqdn
