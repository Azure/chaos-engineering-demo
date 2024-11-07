@description('First part of the resource name')
param nameprefix string

@description('Azure region for resources')
param location string = resourceGroup().location

var experimentName = '${nameprefix}chaos-nsg-deny'
var chaosNsgSelectorId = guid('${nameprefix}-chaos-nsg-selector-id')

resource nsg 'Microsoft.Network/networkSecurityGroups@2023-11-01' existing = {
  name: '${nameprefix}nsg-aks'
}

resource chaosnsgtarget 'Microsoft.Chaos/targets@2022-10-01-preview' = {
  name: 'Microsoft-NetworkSecurityGroup'
  location: location
  scope: nsg
  properties: {}

  // capability: nsg (deny access)
  resource chaosnsgcapability 'capabilities' = {
    name: 'SecurityRule-1.1'
  }
}

// chaos experiment: nsg
resource chaosnsgexperiment 'Microsoft.Chaos/experiments@2024-03-22-preview' = {
  name: experimentName
  location: location
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    selectors: [
      {
        type: 'List'
        id: chaosNsgSelectorId
        targets: [
          {
            id: chaosnsgtarget.id
            type: 'ChaosTarget'
          }
        ]
      }
    ]    
    steps: [
      {
        name: 'step1'
        branches: [
          {
            name: 'branch1'
            actions: [
              {
                name: 'urn:csci:microsoft:networkSecurityGroup:securityRule/1.1'
                type: 'continuous'
                selectorId: chaosNsgSelectorId
                duration: 'PT5M'
                parameters: [
                  {
                    key: 'direction'
                    value: 'Inbound'
                  }
                  {
                    key: 'sourceAddresses'
                    value: '["0.0.0.0/0"]'
                  }
                  {
                    key: 'sourcePortRanges'
                    value: '["0-65535"]'
                  }
                  {
                    key: 'destinationAddresses'
                    value: '["0.0.0.0/0"]'
                  }
                  {
                    key: 'destinationPortRanges'
                    value: '["0-65535"]'
                  }
                  {
                    key: 'protocol'
                    value: 'Any'
                  }
                  {
                    key: 'action'
                    value: 'Deny'
                  }
                  {
                    key: 'priority'
                    value: '100'
                  }
                  {
                    key: 'name'
                    value: 'DenyAllOutBound'
                  }
                  {
                    key: 'flushConnection'
                    value: 'false'
                  }
                ]
              }
            ]
          }
        ]
      }
    ]
  }
}

// Define the role definition for the Chaos experiment
resource chaosNSGRoleDefinition 'Microsoft.Authorization/roleDefinitions@2022-04-01' existing = {
  scope: nsg
  // "NSG Contributor" -- see https://learn.microsoft.com/en-us/azure/role-based-access-control/built-in-roles#network-contributor 
  name: '4d97b98b-1d4f-4787-a291-c67834d212e7'
}

// Define the role assignment for the Chaos experiment - NSG
resource chaosRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(nsg.id, chaosnsgexperiment.id, chaosNSGRoleDefinition.id)
  scope: nsg
  properties: {
    roleDefinitionId: chaosNSGRoleDefinition.id
    principalId: chaosnsgexperiment.identity.principalId
    principalType: 'ServicePrincipal'
  }
}
