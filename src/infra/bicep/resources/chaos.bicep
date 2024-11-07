@description('First part of the resource name')
param nameprefix string

@description('Azure region for resources')
param location string = resourceGroup().location

param aksClusterResourceGroup string

param uamiName string

// First experiment: Disable a VMSS node
module chaos1 '../chaos-experiments/chaos-vmss-disable-node.bicep' = {
  name: '${nameprefix}-chaos-1'
  params: {
    nameprefix: nameprefix
    location: location
  }
}

// Second experiment: Deny access to a Key Vault
module chaos2 '../chaos-experiments/chaos-keyvault-deny.bicep' = {
  name: '${nameprefix}-chaos-2'
  params: {
    nameprefix: nameprefix
    location: location
  }
}

// Third experiment: Degradation of an AKS cluster
module chaos3 '../chaos-experiments/chaos-aks-degradation.bicep' = {
  name: '${nameprefix}-chaos-3'
  params: {
    nameprefix: nameprefix
    location: location
  }
}

// Deployment Script: Get the VMSS Cluster Name
module deploymentScript '../utils/aks-deploymentscript.bicep' = {
  name: '${nameprefix}-deploymentScript'
  params: {
    nameprefix: nameprefix
    location: location
    aksClusterResourceGroup: aksClusterResourceGroup
    uamiName: uamiName
  }
  dependsOn: [
    chaos1
    chaos2
    chaos3
  ]
}

// Forth experiment: AKS cluster zone down
module chaos4 '../chaos-experiments/chaos-zone-down.bicep' = {
  name: '${nameprefix}-chaos-4'
  scope: resourceGroup(aksClusterResourceGroup)
  params: {
    nameprefix: nameprefix
    location: location
    vmssClusterName: deploymentScript.outputs.vmssClusterName
  }
}

// Fifth experiment: Deny NSG access to Cart
module chaos5 '../chaos-experiments/chaos-nsg-deny.bicep' = {
  name: '${nameprefix}-chaos-5'
  params: {
    nameprefix: nameprefix
    location: location
  }
}

// References to next experiments to be added here. 
