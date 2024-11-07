@description('User Manage Identity Role Name')
param uamiName  string

@description('User Manage Identity Resource Group Name')
param uamiRg string

// Reference the existing user assigned managed identity
resource userAssignedIdentityDS 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' existing = {
  name: uamiName
  scope: resourceGroup(uamiRg)
}

// Assign the Contributor role to the user assigned managed identity
resource contributorRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {  
  name: guid(resourceGroup().id, userAssignedIdentityDS.id, 'b24988ac-6180-42a0-ab88-20f7382dd24c') // Contributor role ID    
  scope: resourceGroup()
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', 'b24988ac-6180-42a0-ab88-20f7382dd24c') // Contributor role ID
    principalId: userAssignedIdentityDS.properties.principalId
    principalType: 'ServicePrincipal'    
  }
}

// Assign the Managed Identity Operator role to the user assigned managed identity
resource managedIdentityOperatorRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(resourceGroup().id, userAssignedIdentityDS.id, 'f1a07417-d97a-45cb-824c-7a7467783830') // Managed Identity Operator role ID
  scope: resourceGroup()
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', 'f1a07417-d97a-45cb-824c-7a7467783830') // Managed Identity Operator role ID
    principalId: userAssignedIdentityDS.properties.principalId
    principalType: 'ServicePrincipal'
  }
}
