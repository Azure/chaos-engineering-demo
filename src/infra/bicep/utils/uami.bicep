@description('First part of the resource name')
param nameprefix string

@description('Azure region for resources')
param location string = resourceGroup().location

// Define the user assigned managed identity
resource userAssignedIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' = {
  name: '${nameprefix}userAssignedIdentity'
  location: location
}

output userAssignedIdentityName string = userAssignedIdentity.name
output userAssignedIdentityPrincipalId string = userAssignedIdentity.properties.principalId
output userAssignedIdentityId string = userAssignedIdentity.id
