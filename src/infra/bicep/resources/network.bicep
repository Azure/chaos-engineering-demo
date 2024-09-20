@description('First part of the resource name')
param nameprefix string

@description('Azure region for resources')
param location string = resourceGroup().location

@description('Log Analytics workspace ID for diagnostic settings')
param logAnalyticsId string

var vnetName = '${nameprefix}vnet01'
var vnetAddressPrefix = '10.12.0.0/16'
var aksSubnetName = 'aks'
var aksSubnetPrefix = '10.12.0.0/23'
var aksSubnetNSGName = '${nameprefix}nsg-aks'
var acaSubnetName = 'aca'
var acaSubnetPrefix = '10.12.2.0/23'
var acaSubnetNSGName = '${nameprefix}nsg-aca'

resource vnet 'Microsoft.Network/virtualNetworks@2021-08-01' = {
  name: vnetName
  location: location
  properties: {
    addressSpace: {
      addressPrefixes: [
        vnetAddressPrefix
      ]
    }
    subnets: [
      {
        name: aksSubnetName
        properties: {
          addressPrefix: aksSubnetPrefix
           networkSecurityGroup: {
             id: resourceId('Microsoft.Network/networkSecurityGroups', aksSubnetNSGName)
           }
        }
      }
      {
        name: acaSubnetName
        properties: {
          addressPrefix: acaSubnetPrefix
          networkSecurityGroup: {
            id: resourceId('Microsoft.Network/networkSecurityGroups', acaSubnetNSGName)
          }
        }
      }
    ]
  }
  dependsOn: [
    nsgAks
    nsgAca
  ]
}

resource vnetDiagnostics 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  name: 'metrics-to-loganalytics'
  scope: vnet
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

resource nsgAks 'Microsoft.Network/networkSecurityGroups@2021-02-01' = {
  name: aksSubnetNSGName
  location: location
  properties: {
    securityRules: [
      {
        name: 'Allow-Inbound-Internet-80'
        properties: {
          access: 'Allow'
          direction: 'Inbound'
          protocol: 'Tcp'
          destinationAddressPrefix: aksSubnetPrefix
          destinationPortRange: '80'
          priority: 1000          
          sourceAddressPrefix: 'Internet'
          sourcePortRange: '*'
        }
      }
      {
        name: 'Allow-Inbound-Internet-443'
        properties: {
          access: 'Allow'
          direction: 'Inbound'
          protocol: 'Tcp'
          destinationAddressPrefix: aksSubnetPrefix
          destinationPortRange: '443'
          priority: 1001          
          sourceAddressPrefix: 'Internet'
          sourcePortRange: '*'
        }
      }
      {
        name: 'Allow-Inbound-FrontDoor'
        properties: {
          access: 'Allow'
          direction: 'Inbound'
          protocol: 'Tcp'
          destinationAddressPrefix: '*'
          destinationPortRange: '*'
          priority: 1002          
          sourceAddressPrefix: 'AzureFrontDoor.Backend' 
          sourcePortRange: '*'
        }
      }
    ]
  }
}

resource nsgAca 'Microsoft.Network/networkSecurityGroups@2021-02-01' = {
  name: acaSubnetNSGName
  location: location
  properties: {
    securityRules: [
      {
        name: 'Allow-Inbound-Internet-80'
        properties: {
          access: 'Allow'
          direction: 'Inbound'
          protocol: 'Tcp'
          destinationAddressPrefix: acaSubnetPrefix
          destinationPortRange: '80'
          priority: 1000          
          sourceAddressPrefix: 'Internet'
          sourcePortRange: '*'
        }
      }
      {
        name: 'Allow-Inbound-Internet-443'
        properties: {
          access: 'Allow'
          direction: 'Inbound'
          protocol: 'Tcp'
          destinationAddressPrefix: acaSubnetPrefix
          destinationPortRange: '443'
          priority: 1001
          sourceAddressPrefix: 'Internet'
          sourcePortRange: '*'
        }
      }
      {
        name: 'Allow-Inbound-FrontDoor'
        properties: {
          access: 'Allow'
          direction: 'Inbound'
          protocol: 'Tcp'
          destinationAddressPrefix: '*'
          destinationPortRange: '*'
          priority: 1002          
          sourceAddressPrefix: 'AzureFrontDoor.Backend' 
          sourcePortRange: '*'
        }
      }
    ]
  }
}

output vnetName string = vnetName
output vnetAksSubnetName string = aksSubnetName
output vnetAcaSubnetName string = acaSubnetName
output aksSubnetPrefix string = aksSubnetPrefix
output acaSubnetPrefix string = acaSubnetPrefix
