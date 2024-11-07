@description('First part of the resource name')
param nameprefix string

@description('Azure region for resources')
param location string = resourceGroup().location

param vmssClusterName string

param chaosvmssExperimentName string = '${nameprefix}chaos-zone-down'

param chaosAksSelectorId string = guid('${nameprefix}-chaos-aks-selector-id')

// Reference the existing VMSS resource
resource vmss 'Microsoft.Compute/virtualMachineScaleSets@2023-09-01' existing = {
  name: vmssClusterName 
}

// target: VMSS
resource chaosvmsstarget 'Microsoft.Chaos/targets@2022-10-01-preview' = {
  name: 'Microsoft-VirtualMachineScaleSet'
  location: location
  scope: vmss
  properties: {}

  // capability: vmss (shutdown)
  resource chaosvmsscappod 'capabilities' = {
    name: 'Shutdown-2.0'
  }
}

// chaos experiment: vmss
resource chaosvmssexperiment 'Microsoft.Chaos/experiments@2022-10-01-preview' = {
  name: chaosvmssExperimentName
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
            id: chaosvmsstarget.id
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
                name: 'urn:csci:microsoft:virtualMachineScaleSet:shutdown/2.0'
                type: 'continuous'
                selectorId: chaosAksSelectorId
                duration: 'PT5M'
                parameters: [
                  {
                    key: 'abruptShutdown'
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
resource chaosvmssRoleDefinition 'Microsoft.Authorization/roleDefinitions@2022-04-01' existing = {
  scope: vmss
  // "Virtual Machine Contributor" -- see https://learn.microsoft.com/azure/role-based-access-control/built-in-roles 
  name: '9980e02c-c2be-4d73-94e8-173b1dc7cf3c'
}

// Define the role assignment for the Chaos experiment - VMSS
resource chaosRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(vmss.id, chaosvmssexperiment.id, chaosvmssRoleDefinition.id)
  scope: vmss
  properties: {
    roleDefinitionId: chaosvmssRoleDefinition.id
    principalId: chaosvmssexperiment.identity.principalId
    principalType: 'ServicePrincipal'
  }
}
