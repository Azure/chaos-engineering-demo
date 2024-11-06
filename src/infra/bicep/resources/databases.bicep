@description('First part of the resource name')
param nameprefix string

@description('Azure region for resources')
param location string = resourceGroup().location

@description('Set zone redundancy for all resources')
param zoneRedundant bool = false

@description('The name of the key vault used for the application')
param keyvaultName string

@description('Log Analytics workspace ID for diagnostic settings')
param logAnalyticsId string

var sqlServerHostName = environment().suffixes.sqlServerHostname
var sqlServerName = '${nameprefix}sqlserver'

var sqlProductsDatabaseName = '${nameprefix}sql-products-db'
var sqlProfilesDatabaseName = '${nameprefix}sql-profiles-db'

var cosmosStocksDatabaseName = '${nameprefix}cosmos-stocks'
var cosmosCartsDatabaseName = '${nameprefix}cosmos-carts'

var connectionStringProducts = 'productsDbConnectionString'
var connectionStringProfiles = 'profilesDbConnectionString'
var connectionStringStocks = 'stocksDbConnectionString'
var connectionStringCarts = 'cartsDbConnectionString'

resource keyvault 'Microsoft.KeyVault/vaults@2023-07-01' existing = {
  name: keyvaultName
}

// SQL Azure resources:

resource sqlServer 'Microsoft.Sql/servers@2023-05-01-preview' = {
  name: sqlServerName
  location: location
  properties: {
    version: '12.0'
  }

  resource db_fw_allowazureresources 'firewallRules' = {
    name: 'AllowAllWindowsAzureIps'
    properties: {
      endIpAddress: '0.0.0.0'
      startIpAddress: '0.0.0.0'
    }
  }
}

resource sqlServerDiagnostics 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  name: 'metrics-to-loganalytics'
  scope: sqlServer
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

resource productsdb 'Microsoft.Sql/servers/databases@2023-05-01-preview' = {
  name: sqlProductsDatabaseName
  parent: sqlServer
  location: location
  sku: {
    capacity: zoneRedundant ? 4 : 5
    tier: zoneRedundant ? 'GeneralPurpose' : 'Basic'
    name: zoneRedundant ? 'GP_Gen5_4' : 'Basic'
  }
  properties: {
    zoneRedundant: zoneRedundant
  }
}

resource profilesdb 'Microsoft.Sql/servers/databases@2023-05-01-preview' = {
  name: sqlProfilesDatabaseName
  parent: sqlServer
  location: location
  sku: {
    capacity: zoneRedundant ? 4 : 5
    tier: zoneRedundant ? 'GeneralPurpose' : 'Basic'
    name: zoneRedundant ? 'GP_Gen5_4' : 'Basic'
  }
  properties: {
    zoneRedundant: zoneRedundant
  }
}

// CosmosDB Resources:

resource cosmosStocks 'Microsoft.DocumentDB/databaseAccounts@2022-08-15' = {
  name: cosmosStocksDatabaseName
  location: location
  properties: {
    databaseAccountOfferType: 'Standard'
    enableFreeTier: false
    capabilities: [
      {
        name: 'EnableServerless'
      }
    ]
    locations: [
      {
        locationName: location
        isZoneRedundant: zoneRedundant
      }
    ]
  }
}

resource cosmosStocksDiagnostics 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  name: 'metrics-to-loganalytics'
  scope: cosmosStocks
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

resource cosmosStocksDb 'Microsoft.DocumentDB/databaseAccounts/sqlDatabases@2024-05-15' = {
  name: '${cosmosStocksDatabaseName}db'
  parent: cosmosStocks
  location: location
  properties: {
    resource: {
      id: '${cosmosStocksDatabaseName}db'
    }
  }

  resource stocksdb_container 'containers' = {
    name: '${cosmosStocksDatabaseName}dbc'
    location: location
    properties: {
      resource: {
        id: '${cosmosStocksDatabaseName}dbc'
        partitionKey: {
          paths: [
            '/id'
          ]
        }
      }
    }
  }
}

resource cosmosCarts 'Microsoft.DocumentDB/databaseAccounts@2022-08-15' = {
  name: cosmosCartsDatabaseName
  location: location
  properties: {
    databaseAccountOfferType: 'Standard'
    enableFreeTier: false
    capabilities: [
      {
        name: 'EnableServerless'
      }
    ]
    locations: [
      {
        locationName: location
      }
    ]
  }
}

resource cosmosCartsDiagnostics 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  name: 'metrics-to-loganalytics'
  scope: cosmosCarts
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

resource cosmosCartsDb 'Microsoft.DocumentDB/databaseAccounts/sqlDatabases@2024-05-15' = {
  name: '${cosmosCartsDatabaseName}db'
  parent: cosmosCarts
  location: location
  properties: {
    resource: {
      id: '${cosmosCartsDatabaseName}db'
    }
  }

  resource cartsdb_container 'containers' = {
    name: '${cosmosCartsDatabaseName}dbc'
    location: location
    properties: {
      resource: {
        id: '${cosmosCartsDatabaseName}dbc'
        partitionKey: {
          paths: [
            '/Email'
          ]
        }
      }
    }
  }
}

// The following secrets from the database creation are stored in the key vault:

resource secretProductsDbConnectionString 'Microsoft.KeyVault/vaults/secrets@2023-07-01' = {
  parent: keyvault
  name: connectionStringProducts
  properties: {
    value: 'Server=tcp:${sqlServerName}${sqlServerHostName},1433;Initial Catalog=${sqlProductsDatabaseName};Encrypt=True;TrustServerCertificate=False;Connection Timeout=30;Authentication=Active Directory Default;'
  }
}

resource secretProfilesDbConnectionString 'Microsoft.KeyVault/vaults/secrets@2023-07-01' = {
  parent: keyvault
  name: connectionStringProfiles
  properties: {
    value: 'Server=tcp:${sqlServerName}${sqlServerHostName},1433;Initial Catalog=${sqlProfilesDatabaseName};Encrypt=True;TrustServerCertificate=False;Connection Timeout=30;Authentication=Active Directory Default;'
  }
}

resource secretCosmosStocksConnectionString 'Microsoft.KeyVault/vaults/secrets@2023-07-01' = {
  parent: keyvault
  name: connectionStringStocks
  properties: {
    value: cosmosStocks.listConnectionStrings().connectionStrings[0].connectionString
  }
}

resource secretCosmosCartsConnectionString 'Microsoft.KeyVault/vaults/secrets@2023-07-01' = {
  parent: keyvault
  name: connectionStringCarts
  properties: {
    value: cosmosCarts.listConnectionStrings().connectionStrings[0].connectionString
  }
}

// We need to store the CosmosDB Database and Container names in KeyVault as Secrets as well
resource secretCosmosCartsDb 'Microsoft.KeyVault/vaults/secrets@2023-07-01' = {
  parent: keyvault
  name: 'cartsDbName'
  properties: {
    value: cosmosCartsDb.name
  }
}
resource secretCosmosCartsDbConatiner 'Microsoft.KeyVault/vaults/secrets@2023-07-01' = {
  parent: keyvault
  name: 'cartsDbContainerName'
  properties: {
    value: '${cosmosCartsDatabaseName}dbc'
  }
}
resource secretCosmosStocksDb 'Microsoft.KeyVault/vaults/secrets@2023-07-01' = {
  parent: keyvault
  name: 'stocksDbName'
  properties: {
    value: cosmosStocksDb.name
  }
}
resource secretCosmosStocksDbContainer 'Microsoft.KeyVault/vaults/secrets@2023-07-01' = {
  parent: keyvault
  name: 'stocksDbContainerName'
  properties: {
    value: '${cosmosStocksDatabaseName}dbc'
  }
}

output sqlServerName string = sqlServer.name
output sqlProductsDatabaseName string = productsdb.name
output sqlProfilesDatabaseName string = profilesdb.name
output cosmosStocksDatabaseName string = cosmosStocks.name
