// This experiment simulates a denial of access to a Key Vault.
// This may be useful to test the resilience of your application to such an event,
// and may also simulate general unavailability of a keyvault as a failure mode. 
// 
// To protect against this, mitigations apply at the infrastructure and application level:
// 1) It is highly recommended to use Zone Redundant resources for production workloads
// 2) Ensure that your application has a retry policy in place for Key Vault access, including an exponential backoff
// 3) Ensure that your application has a fallback mechanism in place for Key Vault access, such as using a local cache. 
//    Secret access should not be a blocking operation for your application, but rather a background task that can be retried.
//    For example, consider retrieving a set of secrets at application startup and refreshing them periodically in the background and directly upon an authentication failure. 

@description('First part of the resource name')
param nameprefix string

@description('Azure region for resources')
param location string = resourceGroup().location

var experimentName = '${nameprefix}chaos-keyvault-deny'
var chaosKvSelectorId = guid('${nameprefix}-chaos-kv-selector-id')

resource keyvault 'Microsoft.KeyVault/vaults@2023-07-01' existing = {
  name: '${nameprefix}kv'
}

resource chaoskvtarget 'Microsoft.Chaos/targets@2022-10-01-preview' = {
  name: 'Microsoft-KeyVault'
  location: location
  scope: keyvault
  properties: {}

  // capability: kv (deny access)
  resource chaoskvcapability 'capabilities' = {
    name: 'DenyAccess-1.0'
  }
}

// chaos experiment: kv
resource chaoskvexperiment 'Microsoft.Chaos/experiments@2022-10-01-preview' = {
  name: experimentName
  location: location
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    selectors: [
      {
        type: 'List'
        id: chaosKvSelectorId
        targets: [
          {
            id: chaoskvtarget.id
            type: 'ChaosTarget'
          }
        ]
      }
    ]
    startOnCreation: false
    steps: [
      {
        name: 'step1'
        branches: [
          {
            name: 'branch1'
            actions: [
              {
                name: 'urn:csci:microsoft:keyVault:denyAccess/1.0'
                type: 'continuous'
                selectorId: chaosKvSelectorId
                duration: 'PT5M'
                parameters: []
              }
            ]
          }
        ]
      }
    ]
  }
}

// Define the role definition for the Chaos experiment
resource chaosKVRoleDefinition 'Microsoft.Authorization/roleDefinitions@2022-04-01' existing = {
  scope: keyvault
  // "Key Vault Contributor" -- see https://learn.microsoft.com/en-us/azure/role-based-access-control/built-in-roles#key-vault-contributor 
  name: 'f25e0fa2-a7c8-4377-a976-54943a77a395'
}

// Define the role assignment for the Chaos experiment - Key Vault
resource chaosRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {  
  name: guid(keyvault.id, chaoskvexperiment.id, chaosKVRoleDefinition.id) 
  scope: keyvault
  properties: {
    roleDefinitionId: chaosKVRoleDefinition.id
    principalId: chaoskvexperiment.identity.principalId
    principalType: 'ServicePrincipal'
  }
}
