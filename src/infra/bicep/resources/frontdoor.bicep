@description('First part of the resource name')
param nameprefix string

// Note that Frontdoor is always zone redundant and always in all regions, so we don't need params for that

@description('The backend url for the Products API')
param productsApiUrl string

@description('The backend url for the Carts API')
param cartsApiUrl string

@description('The backend url for the Web App')
param webUrl string

@description('The backend url for the image store')
param imageUrl string

@description('Log Analytics workspace ID for diagnostic settings')
param logAnalyticsId string

// General resource definitions:
resource frontdoor 'Microsoft.Cdn/profiles@2021-06-01' = {
  name: '${nameprefix}afd'
  location: 'Global'
  sku: {
    name: 'Standard_AzureFrontDoor'
  }
  properties: {
    originResponseTimeoutSeconds: 60
  }
}

resource frontDoorDiagnostics 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  name: 'metrics-to-loganalytics'
  scope: frontdoor
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

resource afdendpoint 'Microsoft.Cdn/profiles/afdendpoints@2021-06-01' = {
  parent: frontdoor
  name: nameprefix
  location: 'Global'
  properties: {
    enabledState: 'Enabled'
  }
}

// Products API

resource afdorigingroup_productsapi 'Microsoft.Cdn/profiles/origingroups@2021-06-01' = {
  parent: frontdoor
  name: 'origingroup-productsapi'
  properties: {
    loadBalancingSettings: {
      sampleSize: 4
      successfulSamplesRequired: 3
      additionalLatencyInMilliseconds: 50
    }
    sessionAffinityState: 'Disabled'
  }
}

resource afdorigin_productsapi 'Microsoft.Cdn/profiles/origingroups/origins@2021-06-01' = {
  parent: afdorigingroup_productsapi
  name: 'origin-productsapi'
  properties: {
    hostName: productsApiUrl
    httpPort: 80
    httpsPort: 443
    originHostHeader: productsApiUrl
    priority: 1
    weight: 1000
    enabledState: 'Enabled'
    enforceCertificateNameCheck: true
  }
}

resource afdroute_productsapi 'Microsoft.Cdn/profiles/afdendpoints/routes@2021-06-01' = {
  parent: afdendpoint
  name: 'route-productsapi'
  properties: {
    customDomains: []
    originGroup: {
      id: afdorigingroup_productsapi.id
    }
    ruleSets: []
    supportedProtocols: [
      'Http'
      'Https'
    ]
    patternsToMatch: [
      '/v1/products/*'
      '/v1/stocks/*'
    ]
    forwardingProtocol: 'MatchRequest'
    linkToDefaultDomain: 'Enabled'
    httpsRedirect: 'Enabled'
    enabledState: 'Enabled'
  }
  dependsOn: [
    afdorigin_productsapi
  ]
}

// Carts API

resource afdorigingroup_cartsapi 'Microsoft.Cdn/profiles/origingroups@2021-06-01' = {
  parent: frontdoor
  name: 'origingroup-cartsapi'
  properties: {
    loadBalancingSettings: {
      sampleSize: 4
      successfulSamplesRequired: 3
      additionalLatencyInMilliseconds: 50
    }
    sessionAffinityState: 'Disabled'
  }
}

resource afdorigin_cartsapi 'Microsoft.Cdn/profiles/origingroups/origins@2021-06-01' = {
  parent: afdorigingroup_cartsapi
  name: 'origin-cartsapi'
  properties: {
    hostName: cartsApiUrl
    httpPort: 80
    httpsPort: 443
    originHostHeader: cartsApiUrl
    priority: 1
    weight: 1000
    enabledState: 'Enabled'
    enforceCertificateNameCheck: true
  }
}

resource afdroute_cartsapi 'Microsoft.Cdn/profiles/afdendpoints/routes@2021-06-01' = {
  parent: afdendpoint
  name: 'route-cartsapi'
  properties: {
    customDomains: []
    originGroup: {
      id: afdorigingroup_cartsapi.id
    }
    ruleSets: []
    supportedProtocols: [
      'Http'
      'Https'
    ]
    patternsToMatch: [
      '/v1/carts/*'
      '/v1/shoppingcart'
      '/v1/shoppingcart/*'
    ]
    forwardingProtocol: 'MatchRequest'
    linkToDefaultDomain: 'Enabled'
    httpsRedirect: 'Enabled'
    enabledState: 'Enabled'
  }
  dependsOn: [
    afdorigin_cartsapi
  ]
}

// Web App

resource afdorigingroup_web 'Microsoft.Cdn/profiles/origingroups@2021-06-01' = {
  parent: frontdoor
  name: 'origingroup-web'
  properties: {
    loadBalancingSettings: {
      sampleSize: 4
      successfulSamplesRequired: 3
      additionalLatencyInMilliseconds: 50
    }
    sessionAffinityState: 'Disabled'
  }
}



resource afdorigin_web 'Microsoft.Cdn/profiles/origingroups/origins@2021-06-01' = {
  parent: afdorigingroup_web
  name: 'origin-web'
  properties: {
    hostName: webUrl
    httpPort: 80
    httpsPort: 443
    originHostHeader: webUrl
    priority: 1
    weight: 1000
    enabledState: 'Enabled'
    enforceCertificateNameCheck: true
  }
}


resource afdroute_web 'Microsoft.Cdn/profiles/afdendpoints/routes@2021-06-01' = {
  parent: afdendpoint
  name: 'route-web'
  properties: {
    customDomains: []
    originGroup: {
      id: afdorigingroup_web.id
    }
    originPath: '/'
    ruleSets: []
    supportedProtocols: [
      'Http'
      'Https'
    ]
    patternsToMatch: [
      '/*'
    ]
    forwardingProtocol: 'HttpsOnly'
    linkToDefaultDomain: 'Enabled'
    httpsRedirect: 'Enabled'
    enabledState: 'Enabled'
  }
  dependsOn: [
    afdorigin_web
  ]
}

// Image storage

resource afdorigingroup_image 'Microsoft.Cdn/profiles/origingroups@2021-06-01' = {
  parent: frontdoor
  name: 'origingroup-image'
  properties: {
    loadBalancingSettings: {
      sampleSize: 4
      successfulSamplesRequired: 3
      additionalLatencyInMilliseconds: 50
    }
    sessionAffinityState: 'Disabled'
  }
}



resource afdorigin_image 'Microsoft.Cdn/profiles/origingroups/origins@2021-06-01' = {
  parent: afdorigingroup_image
  name: 'origin-image'
  properties: {
    hostName: imageUrl
    httpPort: 80
    httpsPort: 443
    originHostHeader: imageUrl
    priority: 1
    weight: 1000
    enabledState: 'Enabled'
    enforceCertificateNameCheck: true
  }
}


resource afdroute_image_list 'Microsoft.Cdn/profiles/afdendpoints/routes@2021-06-01' = {
  parent: afdendpoint
  name: 'route-image-list'
  properties: {
    customDomains: []
    originGroup: {
      id: afdorigingroup_image.id
    }
    originPath: '/product-list'
    ruleSets: []
    supportedProtocols: [
      'Http'
      'Https'
    ]
    patternsToMatch: [
      '/product-list/*'
    ]
    forwardingProtocol: 'HttpsOnly'
    linkToDefaultDomain: 'Enabled'
    httpsRedirect: 'Enabled'
    enabledState: 'Enabled'
  }
  dependsOn: [
    afdorigin_image
  ]
}

resource afdroute_image_details 'Microsoft.Cdn/profiles/afdendpoints/routes@2021-06-01' = {
  parent: afdendpoint
  name: 'route-image-details'
  properties: {
    customDomains: []
    originGroup: {
      id: afdorigingroup_image.id
    }
    originPath: '/product-details'
    ruleSets: []
    supportedProtocols: [
      'Http'
      'Https'
    ]
    patternsToMatch: [
      '/product-details/*'
    ]
    forwardingProtocol: 'HttpsOnly'
    linkToDefaultDomain: 'Enabled'
    httpsRedirect: 'Enabled'
    enabledState: 'Enabled'
  }
  dependsOn: [
    afdorigin_image
  ]
}

output frontDoorEndpointHostName string = afdendpoint.properties.hostName
output frontDoorName string = frontdoor.name
