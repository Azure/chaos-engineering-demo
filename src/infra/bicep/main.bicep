targetScope = 'subscription'

@minLength(1)
@maxLength(16)
@description('Prefix used for in all resource names, i.e. {name}storage. Alfanumeric characters only. No hyphens.')
param name string = deployment().name

@minLength(1)
@description('Primary location for all resources')
param location string = deployment().location

@description('Set zone redundancy for all resources')
param zoneRedundant bool = false

param deployChaos bool = true

@description('SQLServerAdmin principal')
param sqlServerAdmin object

// The main resource group where all resources will be created
resource rg 'Microsoft.Resources/resourceGroups@2020-06-01' = {
  name: '${name}-rg'
  location: location
}

// The monitoring module contains Log Analytics, which is needed for all diagnostic settings on the resources
module monitoring './resources/monitoring.bicep' = {
  name: '${rg.name}-monitoring'
  scope: rg
  params: {
    nameprefix: toLower(name)
    location: rg.location
  }
}

module network './resources/network.bicep' = {
  name: '${rg.name}-network'
  scope: rg
  params: {
    nameprefix: toLower(name)
    location: rg.location
    logAnalyticsId: monitoring.outputs.logAnalyticsWorkspaceId
  }
}

// The Keyvault deployment only deploys the Keyvault resource first. 
// Various other deployments can later add secrets and/or role assignments to it.
module keyvault './resources/keyvault.bicep' = {
  name: '${rg.name}-keyvault'
  scope: rg
  params: {
    nameprefix: toLower(name)
    location: rg.location
    logAnalyticsId: monitoring.outputs.logAnalyticsWorkspaceId
  }
}

module storage './resources/storage.bicep' = {
  name: '${rg.name}-storage'
  scope: rg
  params: {
    nameprefix: toLower(name)
    location: rg.location 
    zoneRedundant: zoneRedundant
    logAnalyticsId: monitoring.outputs.logAnalyticsWorkspaceId
  }
}

module containers './resources/containers.bicep' = {
  name: '${rg.name}-containers'
  scope: rg
  params: {
    nameprefix: toLower(name)
    location: rg.location
    zoneRedundant: zoneRedundant
    vnetName: network.outputs.vnetName
    aksSubnetName: network.outputs.vnetAksSubnetName
    acaSubnetName: network.outputs.vnetAcaSubnetName
    keyvaultName: keyvault.outputs.keyvaultName
    logAnalyticsId: monitoring.outputs.logAnalyticsWorkspaceId
  }
  dependsOn: [
    network
    keyvault
  ]
}

module databases './resources/databases.bicep' = {
  name: '${rg.name}-databases'
  scope: rg
  params: {
    nameprefix: toLower(name)
    location: rg.location
    zoneRedundant: zoneRedundant
    keyvaultName: keyvault.outputs.keyvaultName
    logAnalyticsId: monitoring.outputs.logAnalyticsWorkspaceId
    sqlServerAdmin: sqlServerAdmin
  }
  dependsOn: [
    keyvault
  ]
}


module frontdoor './resources/frontdoor.bicep' = {
  name: '${rg.name}-frontdoor'
  scope: rg
  params: {
    nameprefix: toLower(name)
    productsApiUrl: containers.outputs.aksClusterFqdn
    cartsApiUrl: containers.outputs.acaAppFqdn
    webUrl: storage.outputs.staticUIWebsiteUrl
    imageUrl: storage.outputs.staticImageWebsiteUrl
    logAnalyticsId: monitoring.outputs.logAnalyticsWorkspaceId
  }
}

// We only deploy the User Assigned Manage Identity if deployChaos is set to true
module uami './utils/uami.bicep' = if (deployChaos) {
  name: '${rg.name}-uami'
  scope: rg
  params: {
    nameprefix: toLower(name)
    location: rg.location
  }
}

// We only deploy the Role Assigment for the main RG if deployChaos is set to true
module roleassigmentrg './utils/uami-roleassigment-rg.bicep' = if (deployChaos) {
  name: '${rg.name}-roleassigmentrg'
  scope: rg
  params: {
    uamiName: (deployChaos) ? uami.outputs.userAssignedIdentityName : ''
    uamiRg: rg.name
  }
}

// We only deploy the Role Assigment for the VMSS RG if deployChaos is set to true
module roleassigmentrgvmss './utils/uami-roleassigment-rg.bicep' = if (deployChaos) {
  name: '${rg.name}-roleassigmentrgvmss'
  scope: resourceGroup('${name}-aks-rg')
  params: {
    uamiName: (deployChaos) ? uami.outputs.userAssignedIdentityName : ''
    uamiRg: rg.name
  }
  // We want to deploy this after the AKS:
  dependsOn: [
    containers
  ]
}

// We only deploy the Chaos experiments if deployChaos is set to true
module chaos './resources/chaos.bicep' = if (deployChaos) {
  name: '${rg.name}-chaos'
  scope: rg
  params: {
    nameprefix: toLower(name)
    location: rg.location
    aksClusterResourceGroup: containers.outputs.aksClusterResourceGroup
    uamiName: (deployChaos) ? uami.outputs.userAssignedIdentityName : ''
  }
  // We want to deploy this last:
  dependsOn: [
    containers
    keyvault
    databases
    frontdoor
    network
    storage
    monitoring
  ]
}

// Output variables are only added if they are needed further in the deployment process. 
// They will be saved to a file and loaded into the environment variable in subsequent jobs. 
// Make sure these variables do not contain sensitive information!
output rg_Name string = rg.name
output frontdoor_Name string = frontdoor.outputs.frontDoorName
output frontdoor_Endpoint string = frontdoor.outputs.frontDoorEndpointHostName
output acr_Name string = containers.outputs.acrName
output keyvault_Name string = keyvault.outputs.keyvaultName
output keyvault_ID string = keyvault.outputs.keyvaultId
output aksCluster_Name string = containers.outputs.aksClusterName
output aksCluster_KubeletIdentityId string = containers.outputs.aksClusterKubeletIdentity
output aca_AppName string = containers.outputs.acaAppName
output aca_AppFqdn string = containers.outputs.acaAppFqdn
output storage_AccountName_Images string = storage.outputs.imageStorageAccountName
output storage_AccountName_UI string = storage.outputs.uiStorageAccountName
output sql_ServerName string = databases.outputs.sqlServerName
output sql_ProfilesDatabaseName string = databases.outputs.sqlProfilesDatabaseName
output sql_ProductsDatabaseName string = databases.outputs.sqlProductsDatabaseName
output cosmos_StocksDatabaseName string = databases.outputs.cosmosStocksDatabaseName
output entra_authority string = '${environment().authentication.loginEndpoint}${tenant().tenantId}'
