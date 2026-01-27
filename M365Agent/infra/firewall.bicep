// Azure Firewall with Application and Network Rules
// Secures outbound traffic from App Service to Azure OpenAI, Bot Framework, and Microsoft 365

@description('Base name for resources')
param resourceBaseName string

@description('Location for all resources')
param location string = resourceGroup().location

@description('Firewall subnet ID (AzureFirewallSubnet)')
param firewallSubnetId string

@description('Azure Firewall SKU')
@allowed([
  'Standard'
  'Premium'
])
param firewallSku string = 'Standard'

@description('Azure Firewall tier')
@allowed([
  'Standard'
  'Premium'
])
param firewallTier string = 'Standard'

// Public IP for Azure Firewall
resource firewallPublicIP 'Microsoft.Network/publicIPAddresses@2021-05-01' = {
  name: '${resourceBaseName}-fw-pip'
  location: location
  sku: {
    name: 'Standard'
  }
  properties: {
    publicIPAllocationMethod: 'Static'
    publicIPAddressVersion: 'IPv4'
  }
}

// Azure Firewall
resource firewall 'Microsoft.Network/azureFirewalls@2021-05-01' = {
  name: '${resourceBaseName}-fw'
  location: location
  properties: {
    sku: {
      name: 'AZFW_VNet'
      tier: firewallTier
    }
    ipConfigurations: [
      {
        name: 'firewallIpConfig'
        properties: {
          subnet: {
            id: firewallSubnetId
          }
          publicIPAddress: {
            id: firewallPublicIP.id
          }
        }
      }
    ]
    threatIntelMode: 'Alert'
    firewallPolicy: {
      id: firewallPolicy.id
    }
  }
}

// Firewall Policy
resource firewallPolicy 'Microsoft.Network/firewallPolicies@2021-05-01' = {
  name: '${resourceBaseName}-fw-policy'
  location: location
  properties: {
    sku: {
      tier: firewallTier
    }
    threatIntelMode: 'Alert'
  }
}

// Application Rule Collection Group
resource appRuleCollectionGroup 'Microsoft.Network/firewallPolicies/ruleCollectionGroups@2021-05-01' = {
  parent: firewallPolicy
  name: 'ApplicationRuleCollectionGroup'
  properties: {
    priority: 100
    ruleCollections: [
      {
        name: 'AzureServices'
        priority: 100
        ruleCollectionType: 'FirewallPolicyFilterRuleCollection'
        action: {
          type: 'Allow'
        }
        rules: [
          {
            name: 'AllowAzureOpenAI'
            ruleType: 'ApplicationRule'
            protocols: [
              {
                protocolType: 'Https'
                port: 443
              }
            ]
            fqdnTags: []
            targetFqdns: [
              '*.openai.azure.com'
              'openai.azure.com'
            ]
            sourceAddresses: [
              '10.0.0.0/16'  // VNet address space
            ]
          }
          {
            name: 'AllowBotFramework'
            ruleType: 'ApplicationRule'
            protocols: [
              {
                protocolType: 'Https'
                port: 443
              }
            ]
            fqdnTags: []
            targetFqdns: [
              'token.botframework.com'
              'api.botframework.com'
              'login.botframework.com'
            ]
            sourceAddresses: [
              '10.0.0.0/16'
            ]
          }
          {
            name: 'AllowAzureAD'
            ruleType: 'ApplicationRule'
            protocols: [
              {
                protocolType: 'Https'
                port: 443
              }
            ]
            fqdnTags: []
            targetFqdns: [
              'login.microsoftonline.com'
              'login.windows.net'
              'login.microsoft.com'
              '*.login.microsoft.com'
              'graph.microsoft.com'
              '*.graph.microsoft.com'
            ]
            sourceAddresses: [
              '10.0.0.0/16'
            ]
          }
          {
            name: 'AllowMicrosoft365'
            ruleType: 'ApplicationRule'
            protocols: [
              {
                protocolType: 'Https'
                port: 443
              }
            ]
            fqdnTags: []
            targetFqdns: [
              '*.teams.microsoft.com'
              'teams.microsoft.com'
              '*.office.com'
              '*.office365.com'
              '*.microsoftonline.com'
              '*.skype.com'
              '*.outlook.com'
            ]
            sourceAddresses: [
              '10.0.0.0/16'
            ]
          }
          {
            name: 'AllowAzureManagement'
            ruleType: 'ApplicationRule'
            protocols: [
              {
                protocolType: 'Https'
                port: 443
              }
            ]
            fqdnTags: []
            targetFqdns: [
              'management.azure.com'
              '*.management.azure.com'
              'portal.azure.com'
              '*.portal.azure.com'
            ]
            sourceAddresses: [
              '10.0.0.0/16'
            ]
          }
          {
            name: 'AllowAzureStorage'
            ruleType: 'ApplicationRule'
            protocols: [
              {
                protocolType: 'Https'
                port: 443
              }
            ]
            fqdnTags: []
            targetFqdns: [
              '*.blob.core.windows.net'
              '*.table.core.windows.net'
              '*.queue.core.windows.net'
              '*.file.core.windows.net'
            ]
            sourceAddresses: [
              '10.0.0.0/16'
            ]
          }
          {
            name: 'AllowAzureKeyVault'
            ruleType: 'ApplicationRule'
            protocols: [
              {
                protocolType: 'Https'
                port: 443
              }
            ]
            fqdnTags: []
            targetFqdns: [
              '*.vault.azure.net'
              'vault.azure.net'
            ]
            sourceAddresses: [
              '10.0.0.0/16'
            ]
          }
          {
            name: 'AllowAzureMonitor'
            ruleType: 'ApplicationRule'
            protocols: [
              {
                protocolType: 'Https'
                port: 443
              }
            ]
            fqdnTags: []
            targetFqdns: [
              '*.applicationinsights.azure.com'
              '*.monitor.azure.com'
              'dc.services.visualstudio.com'
              '*.in.applicationinsights.azure.com'
            ]
            sourceAddresses: [
              '10.0.0.0/16'
            ]
          }
          {
            name: 'AllowCertificateServices'
            ruleType: 'ApplicationRule'
            protocols: [
              {
                protocolType: 'Http'
                port: 80
              }
            ]
            fqdnTags: []
            targetFqdns: [
              'ocsp.digicert.com'
              'crl3.digicert.com'
              'crl4.digicert.com'
              'ocsp.msocsp.com'
              'mscrl.microsoft.com'
              'crl.microsoft.com'
              'oneocsp.microsoft.com'
              'cacerts.digicert.com'
            ]
            sourceAddresses: [
              '10.0.0.0/16'
            ]
          }
          {
            name: 'AllowNuGetPackages'
            ruleType: 'ApplicationRule'
            protocols: [
              {
                protocolType: 'Https'
                port: 443
              }
            ]
            fqdnTags: []
            targetFqdns: [
              'api.nuget.org'
              '*.nuget.org'
              'nuget.org'
            ]
            sourceAddresses: [
              '10.0.0.0/16'
            ]
          }
        ]
      }
      {
        name: 'AppServiceDependencies'
        priority: 110
        ruleCollectionType: 'FirewallPolicyFilterRuleCollection'
        action: {
          type: 'Allow'
        }
        rules: [
          {
            name: 'AllowAppServiceManagement'
            ruleType: 'ApplicationRule'
            protocols: [
              {
                protocolType: 'Https'
                port: 443
              }
            ]
            fqdnTags: []
            targetFqdns: [
              '*.azurewebsites.net'
              '*.scm.azurewebsites.net'
              'azurewebsites.net'
            ]
            sourceAddresses: [
              '10.0.0.0/16'
            ]
          }
          {
            name: 'AllowWindowsUpdate'
            ruleType: 'ApplicationRule'
            protocols: [
              {
                protocolType: 'Https'
                port: 443
              }
              {
                protocolType: 'Http'
                port: 80
              }
            ]
            fqdnTags: [
              'WindowsUpdate'
            ]
            targetFqdns: []
            sourceAddresses: [
              '10.0.0.0/16'
            ]
          }
          {
            name: 'AllowAppServiceEnvironment'
            ruleType: 'ApplicationRule'
            protocols: [
              {
                protocolType: 'Https'
                port: 443
              }
            ]
            fqdnTags: [
              'AppServiceEnvironment'
            ]
            targetFqdns: []
            sourceAddresses: [
              '10.0.0.0/16'
            ]
          }
        ]
      }
      {
        name: 'AIAndCognitiveServices'
        priority: 120
        ruleCollectionType: 'FirewallPolicyFilterRuleCollection'
        action: {
          type: 'Allow'
        }
        rules: [
          {
            name: 'AllowCognitiveServices'
            ruleType: 'ApplicationRule'
            protocols: [
              {
                protocolType: 'Https'
                port: 443
              }
            ]
            fqdnTags: []
            targetFqdns: [
              '*.cognitiveservices.azure.com'
              'cognitiveservices.azure.com'
              '*.api.cognitive.microsoft.com'
            ]
            sourceAddresses: [
              '10.0.0.0/16'
            ]
          }
        ]
      }
    ]
  }
}

// Network Rule Collection Group
resource networkRuleCollectionGroup 'Microsoft.Network/firewallPolicies/ruleCollectionGroups@2021-05-01' = {
  parent: firewallPolicy
  name: 'NetworkRuleCollectionGroup'
  properties: {
    priority: 200
    ruleCollections: [
      {
        name: 'AzureServiceTags'
        priority: 200
        ruleCollectionType: 'FirewallPolicyFilterRuleCollection'
        action: {
          type: 'Allow'
        }
        rules: [
          {
            name: 'AllowAzureCloud'
            ruleType: 'NetworkRule'
            ipProtocols: [
              'TCP'
            ]
            sourceAddresses: [
              '10.0.0.0/16'
            ]
            destinationAddresses: [
              'AzureCloud'
            ]
            destinationPorts: [
              '443'
            ]
          }
          {
            name: 'AllowAzureActiveDirectory'
            ruleType: 'NetworkRule'
            ipProtocols: [
              'TCP'
            ]
            sourceAddresses: [
              '10.0.0.0/16'
            ]
            destinationAddresses: [
              'AzureActiveDirectory'
            ]
            destinationPorts: [
              '443'
            ]
          }
          {
            name: 'AllowAzureCognitiveServices'
            ruleType: 'NetworkRule'
            ipProtocols: [
              'TCP'
            ]
            sourceAddresses: [
              '10.0.0.0/16'
            ]
            destinationAddresses: [
              'CognitiveServicesManagement'
            ]
            destinationPorts: [
              '443'
            ]
          }
          {
            name: 'AllowAzureMonitor'
            ruleType: 'NetworkRule'
            ipProtocols: [
              'TCP'
            ]
            sourceAddresses: [
              '10.0.0.0/16'
            ]
            destinationAddresses: [
              'AzureMonitor'
            ]
            destinationPorts: [
              '443'
            ]
          }
          {
            name: 'AllowStorage'
            ruleType: 'NetworkRule'
            ipProtocols: [
              'TCP'
            ]
            sourceAddresses: [
              '10.0.0.0/16'
            ]
            destinationAddresses: [
              'Storage'
            ]
            destinationPorts: [
              '443'
            ]
          }
          {
            name: 'AllowKeyVault'
            ruleType: 'NetworkRule'
            ipProtocols: [
              'TCP'
            ]
            sourceAddresses: [
              '10.0.0.0/16'
            ]
            destinationAddresses: [
              'AzureKeyVault'
            ]
            destinationPorts: [
              '443'
            ]
          }
        ]
      }
      {
        name: 'DNSAndNTP'
        priority: 210
        ruleCollectionType: 'FirewallPolicyFilterRuleCollection'
        action: {
          type: 'Allow'
        }
        rules: [
          {
            name: 'AllowDNS'
            ruleType: 'NetworkRule'
            ipProtocols: [
              'UDP'
            ]
            sourceAddresses: [
              '10.0.0.0/16'
            ]
            destinationAddresses: [
              '168.63.129.16'  // Azure DNS
            ]
            destinationPorts: [
              '53'
            ]
          }
          {
            name: 'AllowNTP'
            ruleType: 'NetworkRule'
            ipProtocols: [
              'UDP'
            ]
            sourceAddresses: [
              '10.0.0.0/16'
            ]
            destinationAddresses: [
              '*'
            ]
            destinationPorts: [
              '123'
            ]
          }
        ]
      }
    ]
  }
  dependsOn: [
    appRuleCollectionGroup
  ]
}

// Outputs
output firewallId string = firewall.id
output firewallName string = firewall.name
output firewallPrivateIP string = firewall.properties.ipConfigurations[0].properties.privateIPAddress
output firewallPublicIP string = firewallPublicIP.properties.ipAddress
output firewallPolicyId string = firewallPolicy.id
