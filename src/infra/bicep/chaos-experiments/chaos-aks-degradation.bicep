@description('First part of the resource name')
param nameprefix string

@description('Azure region for resources')
param location string = resourceGroup().location

var experimentName = '${nameprefix}chaos-aks-degradation'
var chaosAksSelectorId = guid('${nameprefix}-chaos-aks-selector-id')

// Reference the existing AKS resource
resource aks 'Microsoft.ContainerService/managedClusters@2022-10-02-preview' existing = {
  name: '${nameprefix}aks'
}

// target: aks
resource chaosakstarget 'Microsoft.Chaos/targets@2022-10-01-preview' = {
  name: 'Microsoft-AzureKubernetesServiceChaosMesh'
  location: location
  scope: aks
  properties: {}

  // capability: aks (pod failures)
  resource chaosakscappod 'capabilities' = {
    name: 'PodChaos-2.2'
  }
  // capability: aks (stress load)
  resource chaosakscapstress 'capabilities' = {
    name: 'StressChaos-2.2'
  }
}

// chaos experiment: aks (chaos mesh)
resource chaosaksexperiment 'Microsoft.Chaos/experiments@2024-03-22-preview' = {
  name: experimentName
  location: location  
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    selectors: [
      {
        type: 'List'
        id: chaosAksSelectorId
        targets: [
          {
            id: chaosakstarget.id
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
                name: 'urn:csci:microsoft:azureKubernetesServiceChaosMesh:podChaos/2.2'
                type: 'continuous'
                selectorId: chaosAksSelectorId
                duration: 'PT5M'
                parameters: [
                  {
                    key: 'jsonSpec'
                    value: '{"action":"pod-failure","mode":"all","selector":{"namespaces":["default"],"labelSelectors":{"app":"contoso-traders-products"}}}'
                  }
                ]
              }
              {
                name: 'urn:csci:microsoft:azureKubernetesServiceChaosMesh:podChaos/2.2'
                type: 'continuous'
                selectorId: chaosAksSelectorId
                duration: 'PT5M'
                parameters: [
                  {
                    key: 'jsonSpec'
                    value: '{"mode":"all","selector":{"namespaces":["default"],"labelSelectors":{"app":"contoso-traders-products"}},"stressors":{"cpu":{"workers":1,"load":100}}'
                  }
                ]
              }
              {
                name: 'urn:csci:microsoft:azureKubernetesServiceChaosMesh:podChaos/2.2'
                type: 'continuous'
                selectorId: chaosAksSelectorId
                duration: 'PT5M'
                parameters: [
                  {
                    key: 'jsonSpec'
                    value: '{"mode":"all","selector":{"namespaces":["default"],"labelSelectors":{"app":"contoso-traders-products"}},"stressors":{"memory":{"workers":4,"size":"256MB"}}'
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
resource chaosAksRoleDefinitionAdmin 'Microsoft.Authorization/roleDefinitions@2022-04-01' existing = {
  scope: aks
  // "Azure Kubernetes Service Cluster Admin Role" -- see https://learn.microsoft.com/azure/role-based-access-control/built-in-roles 
  name: '0ab0b1a8-8aac-4efd-b8c2-3ee1fb270be8'
}

resource chaosAksRoleDefinitionUser 'Microsoft.Authorization/roleDefinitions@2022-04-01' existing = {
  scope: aks
  // "Azure Kubernetes Service Cluster User Role" -- see https://learn.microsoft.com/azure/role-based-access-control/built-in-roles 
  name: '4abbcc35-e782-43d8-92c5-2d3f1bd2253f'
}

// Define the role assignment for the Chaos experiment - AKS
resource chaosRoleAssignmentAdmin 'Microsoft.Authorization/roleAssignments@2022-04-01' = {  
  name: guid(aks.id, chaosaksexperiment.id, chaosAksRoleDefinitionAdmin.id) 
  scope: aks
  properties: {
    roleDefinitionId: chaosAksRoleDefinitionAdmin.id
    principalId: chaosaksexperiment.identity.principalId
    principalType: 'ServicePrincipal'
  }
}

resource chaosRoleAssignmentUser 'Microsoft.Authorization/roleAssignments@2022-04-01' = {  
  name: guid(aks.id, chaosaksexperiment.id, chaosAksRoleDefinitionUser.id) 
  scope: aks
  properties: {
    roleDefinitionId: chaosAksRoleDefinitionUser.id
    principalId: chaosaksexperiment.identity.principalId
    principalType: 'ServicePrincipal'
  }
}
