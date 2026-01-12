// Private Endpoint for Azure Bot Service
// This must be deployed after the Bot Service is created

@description('Base name for resources')
param resourceBaseName string

@description('Location for all resources')
param location string = resourceGroup().location

@description('Bot Service resource name')
param botServiceName string

@description('VNet resource ID')
param vnetId string

@description('Private endpoints subnet ID')
param privateEndpointsSubnetId string

@description('Bot Service Private DNS Zone ID')
param botServicePrivateDnsZoneId string

// Private Endpoint for Azure Bot Service
resource botServicePrivateEndpoint 'Microsoft.Network/privateEndpoints@2023-05-01' = {
  name: '${resourceBaseName}-botservice-pe'
  location: location
  properties: {
    subnet: {
      id: privateEndpointsSubnetId
    }
    privateLinkServiceConnections: [
      {
        name: '${resourceBaseName}-botservice-plsc'
        properties: {
          privateLinkServiceId: resourceId('Microsoft.BotService/botServices', botServiceName)
          groupIds: [
            'bot'
          ]
        }
      }
    ]
  }
}

// Private DNS Zone Group for Bot Service Private Endpoint
resource botServicePrivateDnsZoneGroup 'Microsoft.Network/privateEndpoints/privateDnsZoneGroups@2023-05-01' = {
  parent: botServicePrivateEndpoint
  name: 'default'
  properties: {
    privateDnsZoneConfigs: [
      {
        name: 'botservice-config'
        properties: {
          privateDnsZoneId: botServicePrivateDnsZoneId
        }
      }
    ]
  }
}

// Outputs
output botServicePrivateEndpointId string = botServicePrivateEndpoint.id
output botServicePrivateEndpointIP string = botServicePrivateEndpoint.properties.customDnsConfigs[0].ipAddresses[0]
