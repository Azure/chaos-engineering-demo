@description('First part of the resource name')
param nameprefix string

@description('Azure region for resources')
param location string = resourceGroup().location

param aksClusterResourceGroup string

param uamiName  string

param scriptName string = '${nameprefix}-deployscript'

resource managedIdentityResource 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31'  existing = {
  name: uamiName 
}

resource script 'Microsoft.Resources/deploymentScripts@2023-08-01' = {
  name: scriptName
  location: location
  kind: 'AzureCLI'
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${managedIdentityResource.id}': {}
    }
  }
  properties: {
    azCliVersion: '2.52.0'
    timeout: 'PT10M'
    retentionInterval: 'P1D'
    cleanupPreference: 'OnSuccess'
    arguments: aksClusterResourceGroup
    scriptContent: 'vmss=$(az vmss list -g ${aksClusterResourceGroup} --query "[].name"); echo $vmss | jq -c \'{name: .[0]}\' > $AZ_SCRIPTS_OUTPUT_PATH'
  }
}

var scriptOutputName = script.properties.outputs.name

output vmssClusterName string = (!empty(scriptOutputName)) ? scriptOutputName : null
