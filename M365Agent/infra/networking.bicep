// VNet and Networking Infrastructure for Travel Agent Bot
// Deploys VNet with subnets for App Service, APIM, and Private Endpoints

@description('Base name for resources')
param resourceBaseName string

@description('Location for all resources')
param location string = resourceGroup().location

@description('VNet address prefix')
param vnetAddressPrefix string = '10.0.0.0/16'

@description('App Service integration subnet prefix')
param appServiceSubnetPrefix string = '10.0.1.0/24'

@description('APIM subnet prefix')
param apimSubnetPrefix string = '10.0.2.0/24'

@description('Private endpoints subnet prefix')
param privateEndpointsSubnetPrefix string = '10.0.3.0/24'

@description('Azure Firewall subnet prefix (must be named AzureFirewallSubnet)')
param firewallSubnetPrefix string = '10.0.4.0/26'

@description('Azure OpenAI resource name (existing)')
param azureOpenAIResourceName string

@description('Azure OpenAI resource group (if different)')
param azureOpenAIResourceGroup string = resourceGroup().name

// Network Security Group for App Service Subnet
resource appServiceNSG 'Microsoft.Network/networkSecurityGroups@2021-05-01' = {
  name: '${resourceBaseName}-appservice-nsg'
  location: location
  properties: {
    securityRules: [
      {
        name: 'AllowAPIMInbound'
        properties: {
          description: 'Allow inbound from APIM subnet'
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '443'
          sourceAddressPrefix: apimSubnetPrefix
          destinationAddressPrefix: appServiceSubnetPrefix
          access: 'Allow'
          priority: 100
          direction: 'Inbound'
        }
      }
      {
        name: 'AllowBotServiceOutbound'
        properties: {
          description: 'Allow outbound to Bot Framework Service via Private Endpoint'
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '443'
          sourceAddressPrefix: appServiceSubnetPrefix
          destinationAddressPrefix: privateEndpointsSubnetPrefix
          access: 'Allow'
          priority: 100
          direction: 'Outbound'
        }
      }
      {
        name: 'AllowBotServiceFallbackOutbound'
        properties: {
          description: 'Allow outbound to Bot Framework Service (fallback to public endpoint)'
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '443'
          sourceAddressPrefix: appServiceSubnetPrefix
          destinationAddressPrefix: 'AzureBotService'
          access: 'Allow'
          priority: 105
          direction: 'Outbound'
        }
      }
      {
        name: 'AllowAzureADOutbound'
        properties: {
          description: 'Allow outbound to Azure AD'
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '443'
          sourceAddressPrefix: appServiceSubnetPrefix
          destinationAddressPrefix: 'AzureActiveDirectory'
          access: 'Allow'
          priority: 110
          direction: 'Outbound'
        }
      }
      {
        name: 'AllowAzureOpenAIOutbound'
        properties: {
          description: 'Allow outbound to Azure OpenAI via Private Endpoint'
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '443'
          sourceAddressPrefix: appServiceSubnetPrefix
          destinationAddressPrefix: privateEndpointsSubnetPrefix
          access: 'Allow'
          priority: 120
          direction: 'Outbound'
        }
      }
    ]
  }
}

// Network Security Group for APIM Subnet
resource apimNSG 'Microsoft.Network/networkSecurityGroups@2021-05-01' = {
  name: '${resourceBaseName}-apim-nsg'
  location: location
  properties: {
    securityRules: [
      {
        name: 'AllowHTTPSInbound'
        properties: {
          description: 'Allow inbound HTTPS from Internet (Teams/Bot Service)'
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '443'
          sourceAddressPrefix: 'Internet'
          destinationAddressPrefix: apimSubnetPrefix
          access: 'Allow'
          priority: 100
          direction: 'Inbound'
        }
      }
      {
        name: 'AllowAPIMManagementInbound'
        properties: {
          description: 'Allow APIM management endpoint'
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '3443'
          sourceAddressPrefix: 'ApiManagement'
          destinationAddressPrefix: 'VirtualNetwork'
          access: 'Allow'
          priority: 110
          direction: 'Inbound'
        }
      }
      {
        name: 'AllowLoadBalancerInbound'
        properties: {
          description: 'Allow Azure Load Balancer'
          protocol: '*'
          sourcePortRange: '*'
          destinationPortRange: '6390'
          sourceAddressPrefix: 'AzureLoadBalancer'
          destinationAddressPrefix: 'VirtualNetwork'
          access: 'Allow'
          priority: 120
          direction: 'Inbound'
        }
      }
      {
        name: 'AllowAppServiceOutbound'
        properties: {
          description: 'Allow outbound to App Service subnet'
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '443'
          sourceAddressPrefix: apimSubnetPrefix
          destinationAddressPrefix: appServiceSubnetPrefix
          access: 'Allow'
          priority: 100
          direction: 'Outbound'
        }
      }
      {
        name: 'AllowStorageOutbound'
        properties: {
          description: 'Allow outbound to Azure Storage'
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '443'
          sourceAddressPrefix: apimSubnetPrefix
          destinationAddressPrefix: 'Storage'
          access: 'Allow'
          priority: 110
          direction: 'Outbound'
        }
      }
      {
        name: 'AllowSQLOutbound'
        properties: {
          description: 'Allow outbound to Azure SQL'
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '1433'
          sourceAddressPrefix: apimSubnetPrefix
          destinationAddressPrefix: 'Sql'
          access: 'Allow'
          priority: 120
          direction: 'Outbound'
        }
      }
      {
        name: 'AllowKeyVaultOutbound'
        properties: {
          description: 'Allow outbound to Key Vault'
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '443'
          sourceAddressPrefix: apimSubnetPrefix
          destinationAddressPrefix: 'AzureKeyVault'
          access: 'Allow'
          priority: 130
          direction: 'Outbound'
        }
      }
    ]
  }
}

// Network Security Group for Private Endpoints Subnet
resource privateEndpointsNSG 'Microsoft.Network/networkSecurityGroups@2021-05-01' = {
  name: '${resourceBaseName}-pe-nsg'
  location: location
  properties: {
    securityRules: [
      {
        name: 'AllowAppServiceInbound'
        properties: {
          description: 'Allow inbound from App Service subnet'
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '443'
          sourceAddressPrefix: appServiceSubnetPrefix
          destinationAddressPrefix: privateEndpointsSubnetPrefix
          access: 'Allow'
          priority: 100
          direction: 'Inbound'
        }
      }
      {
        name: 'AllowAPIMInbound'
        properties: {
          description: 'Allow inbound from APIM subnet for Bot Service connectivity'
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '443'
          sourceAddressPrefix: apimSubnetPrefix
          destinationAddressPrefix: privateEndpointsSubnetPrefix
          access: 'Allow'
          priority: 110
          direction: 'Inbound'
        }
      }
    ]
  }
}

// Virtual Network with NSGs attached to subnets
resource vnet 'Microsoft.Network/virtualNetworks@2021-05-01' = {
  name: '${resourceBaseName}-vnet'
  location: location
  properties: {
    addressSpace: {
      addressPrefixes: [
        vnetAddressPrefix
      ]
    }
    subnets: [
      {
        name: 'appservice-subnet'
        properties: {
          addressPrefix: appServiceSubnetPrefix
          networkSecurityGroup: {
            id: appServiceNSG.id
          }
          delegations: [
            {
              name: 'delegation'
              properties: {
                serviceName: 'Microsoft.Web/serverFarms'
              }
            }
          ]
          serviceEndpoints: []
          privateEndpointNetworkPolicies: 'Disabled'
        }
      }
      {
        name: 'apim-subnet'
        properties: {
          addressPrefix: apimSubnetPrefix
          networkSecurityGroup: {
            id: apimNSG.id
          }
          serviceEndpoints: []
          privateEndpointNetworkPolicies: 'Disabled'
        }
      }
      {
        name: 'privateendpoints-subnet'
        properties: {
          addressPrefix: privateEndpointsSubnetPrefix
          networkSecurityGroup: {
            id: privateEndpointsNSG.id
          }
          serviceEndpoints: []
          privateEndpointNetworkPolicies: 'Disabled'
        }
      }
      {
        name: 'AzureFirewallSubnet'  // Reserved name - must be exactly this
        properties: {
          addressPrefix: firewallSubnetPrefix
          serviceEndpoints: []
          privateEndpointNetworkPolicies: 'Disabled'
        }
      }
    ]
  }
  dependsOn: [
    appServiceNSG
    apimNSG
    privateEndpointsNSG
  ]
}

// Private DNS Zone for Azure OpenAI
resource openAIDnsZone 'Microsoft.Network/privateDnsZones@2020-06-01' = {
  name: 'privatelink.openai.azure.com'
  location: 'global'
}

// Link Private DNS Zone to VNet
resource openAIDnsZoneLink 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2020-06-01' = {
  parent: openAIDnsZone
  name: '${resourceBaseName}-openai-vnet-link'
  location: 'global'
  properties: {
    registrationEnabled: false
    virtualNetwork: {
      id: vnet.id
    }
  }
}

// Private Endpoint for Azure OpenAI
resource openAIPrivateEndpoint 'Microsoft.Network/privateEndpoints@2021-05-01' = {
  name: '${resourceBaseName}-openai-pe'
  location: location
  properties: {
    subnet: {
      id: '${vnet.id}/subnets/privateendpoints-subnet'
    }
    privateLinkServiceConnections: [
      {
        name: '${resourceBaseName}-openai-plsc'
        properties: {
          privateLinkServiceId: resourceId(azureOpenAIResourceGroup, 'Microsoft.CognitiveServices/accounts', azureOpenAIResourceName)
          groupIds: [
            'account'
          ]
        }
      }
    ]
  }
}

// Private DNS Zone Group for OpenAI Private Endpoint
resource openAIPrivateDnsZoneGroup 'Microsoft.Network/privateEndpoints/privateDnsZoneGroups@2021-05-01' = {
  parent: openAIPrivateEndpoint
  name: 'default'
  properties: {
    privateDnsZoneConfigs: [
      {
        name: 'config1'
        properties: {
          privateDnsZoneId: openAIDnsZone.id
        }
      }
    ]
  }
}

// Outputs
output vnetId string = vnet.id
output vnetName string = vnet.name
output appServiceSubnetId string = '${vnet.id}/subnets/appservice-subnet'
output apimSubnetId string = '${vnet.id}/subnets/apim-subnet'
output privateEndpointsSubnetId string = '${vnet.id}/subnets/privateendpoints-subnet'
output firewallSubnetId string = '${vnet.id}/subnets/AzureFirewallSubnet'
output openAIPrivateEndpointId string = openAIPrivateEndpoint.id
output privateDnsZoneId string = openAIDnsZone.id

