@description('First part of the resource name')
param nameprefix string

@description('Azure region for resources')
param location string = resourceGroup().location

@description('Set zone redundancy for all resources')
param zoneRedundant bool = false

@description('VNet name to deploy to')
param vnetName string

@description('Subnet for AKS resources')
param aksSubnetName string

@description('Subnet for ACA resources')
param acaSubnetName string

@description('The name of the key vault used for the application')
param keyvaultName string

@description('The username of the Linux admin for the AKS cluster')
param aksLinuxAdminUsername string = 'contosouser'

@description('Log Analytics workspace ID for diagnostic settings')
param logAnalyticsId string

var acrName = '${nameprefix}registry'
var acrPullRole = resourceId('Microsoft.Authorization/roleDefinitions', '7f951dda-4ed3-4680-a7ca-43fe172d538d')
var sshKeyName = '${nameprefix}-vmss-sshkey'

var aksClusterName = '${nameprefix}aks'
var aksClusterResourceGroup = '${nameprefix}-aks-rg'
var aksDnsPrefix = '${nameprefix}aks'
var aksAutoScaling = true
var aksSubnetResourcesId = resourceId('Microsoft.Network/virtualNetworks/subnets', vnetName, aksSubnetName)

var acaClusterName = '${nameprefix}aca-cluster'
var acaClusterResourceGroup = '${nameprefix}-aca-rg'
var acaCartsContainerAppName = '${nameprefix}aca-carts-app'
var acaCartsContainerDetailsName = '${nameprefix}aca-carts-api'

// Re-defining the already existing keyvault here, so we can reference it and add stuff to it.
resource keyvault 'Microsoft.KeyVault/vaults@2023-07-01' existing = {
  name: keyvaultName
}

resource acr 'Microsoft.ContainerRegistry/registries@2023-07-01' = {
  name: acrName
  location: location
  sku: {
    name: zoneRedundant? 'Premium' : 'Basic'
  }
  properties: {
    adminUserEnabled: true
    publicNetworkAccess: 'Enabled'
    zoneRedundancy: zoneRedundant ? 'Enabled' : 'Disabled'
  }
}

resource acrDiagnostics 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  name: 'metrics-to-loganalytics'
  scope: acr
  properties: {
    metrics: [
      {
        category: 'AllMetrics'
        enabled: true
      }
    ]
    workspaceId: logAnalyticsId
  }
}

resource aks 'Microsoft.ContainerService/managedClusters@2024-03-02-preview' = {
  name: aksClusterName
  location: location
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    dnsPrefix: aksDnsPrefix
    nodeResourceGroup: aksClusterResourceGroup
    networkProfile: {
      networkPlugin: 'azure'
    }
    oidcIssuerProfile: {
      enabled: true
    }
    securityProfile: {
      workloadIdentity: {
        enabled: true
      }
    }

    agentPoolProfiles: [
      {
        name: 'agentpool'
        osDiskSizeGB: 0 // Specifying 0 will apply the default disk size for that agentVMSize. 
        count: 1
        enableAutoScaling: aksAutoScaling
        minCount: 1 // minimum node count
        maxCount: 3 // maximum node count
        vmSize: 'standard_d2s_v4'
        osType: 'Linux'
        mode: 'System'
        availabilityZones: zoneRedundant ? ['1', '2', '3'] : []
        vnetSubnetID: aksSubnetResourcesId
      }
    ]
    linuxProfile: {
      adminUsername: aksLinuxAdminUsername
      ssh: {
        publicKeys: [
          {
            keyData: loadTextContent('../../../../key.pub')
          }
        ]
      }
    }
  }
}

resource aksDiagnostics 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  name: 'metrics-to-loganalytics'
  scope: aks
  properties: {
    metrics: [
      {
        category: 'AllMetrics'
        enabled: true
      }
    ]
    workspaceId: logAnalyticsId
  }
}


resource acrRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(acrName, aks.name)
  scope: acr
  properties: {
    principalId: aks.properties.identityProfile.kubeletidentity.objectId
    roleDefinitionId: acrPullRole
  }
}

resource sshkey 'Microsoft.Compute/sshPublicKeys@2023-07-01' = {
  name: sshKeyName
  location: location
  properties: {
    publicKey:loadTextContent('../../../../key.pub')
  }
}

resource containerenv 'Microsoft.App/managedEnvironments@2023-11-02-preview' = {
  name: acaClusterName
  location: location
  properties: {
    zoneRedundant: zoneRedundant
    infrastructureResourceGroup: acaClusterResourceGroup
    vnetConfiguration: {
      infrastructureSubnetId: resourceId('Microsoft.Network/virtualNetworks/subnets', vnetName, acaSubnetName)
    }
  }
}

resource containerEnvDiagnostics 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  name: 'metrics-to-loganalytics'
  scope: containerenv
  properties: {
    metrics: [
      {
        category: 'AllMetrics'
        enabled: true
      }
    ]
    workspaceId: logAnalyticsId
  }
}

resource cartsApiContainerApp 'Microsoft.App/containerApps@2023-11-02-preview' = {
  name: acaCartsContainerAppName
  location: location
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    environmentId: containerenv.id
    configuration: { 
      ingress: {
        external: true
        allowInsecure: false
        targetPort: 80
      }
      registries: [
        {
          passwordSecretRef: 'acr-password'
          server: acr.properties.loginServer
          username: acr.name
        }
      ]
      secrets: [
        {
          name: 'acr-password'
          value: acr.listCredentials().passwords[0].value
        }
      ]
    }
    template: {
      containers: [
        {
          env: [
            {
              name: 'KeyVaultEndpoint'
              value: keyvault.properties.vaultUri
            }
            {
              name: 'ManagedIdentityClientId'
              value: '' 
              // This value is empty because we want the app to use the SystemAssigned identity:
            }
          ]

          // using a public image initially because no images have been pushed to our private ACR yet
          // at this point. At a later point, our github workflow will update the ACA app to use the 
          // images from our private ACR.
          image: 'mcr.microsoft.com/azuredocs/containerapps-helloworld:latest'
          name: acaCartsContainerDetailsName
          resources: {
            cpu: json('0.5')
            memory: '1.0Gi'
          }
        }
      ]
    }
  }
}

resource containerAppDiagnostics 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  name: 'metrics-to-loganalytics'
  scope: cartsApiContainerApp
  properties: {
    metrics: [
      {
        category: 'AllMetrics'
        enabled: true
      }
    ]
    workspaceId: logAnalyticsId
  }
}

// Add access policies to the keyvault for the AKS cluster and the ACA app
// This ensures that the identities of the resources can retrieve keyvault secrets
resource containerIdentityAccessPolicies 'Microsoft.KeyVault/vaults/accessPolicies@2023-07-01' = {
  parent: keyvault
  name: 'add'
  properties: {
    accessPolicies: [
      {
        tenantId: subscription().tenantId
        objectId: cartsApiContainerApp.identity.principalId
        permissions: {
          secrets: ['get', 'list']
        }
      }
      {
        tenantId: subscription().tenantId
        objectId: aks.properties.identityProfile.kubeletidentity.objectId
        permissions: {
          secrets: ['get', 'list']
        }
      }
    ]
  }
}

resource secretCartsApiEndpoint 'Microsoft.KeyVault/vaults/secrets@2023-07-01' = {
  parent: keyvault
  name: 'cartsApiEndpoint'
  properties: {
    contentType: 'endpoint url (fqdn) of the carts api'
    value: cartsApiContainerApp.properties.configuration.ingress.fqdn
  }
}

output aksClusterName string = aks.name
output aksClusterFqdn string = aks.properties.fqdn
output aksClusterKubeletIdentity string = aks.properties.identityProfile.kubeletidentity.objectId
output aksClusterResourceGroup string = aksClusterResourceGroup
output acrName string = acr.name
output acaAppFqdn string = cartsApiContainerApp.properties.configuration.ingress.fqdn
output acaAppName string = cartsApiContainerApp.name
