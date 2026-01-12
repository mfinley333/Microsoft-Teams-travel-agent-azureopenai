@maxLength(20)
@minLength(4)
@description('Used to generate names for all resources in this file')
param resourceBaseName string

param azureOpenAIEndpoint string
param azureOpenAIDeploymentName string

// Azure AD Authentication for Azure OpenAI
// When using Managed Identity, these parameters are not needed
param useManagedIdentity string = 'true'

param webAppSKU string

@maxLength(42)
param botDisplayName string

param environment string
param botDomain string = ''
param deployAppService bool = environment != 'local'

// For OAuth connection of bot service, created outside of Bicep
param aadAppClientId string = ''
@secure()
param aadAppClientSecret string = ''
param aadAppTenantId string = ''

// VNet and APIM Parameters
param deployVNet bool = true
param azureOpenAIResourceName string = 'aif-travelagent-bot'
param azureOpenAIResourceGroup string = resourceGroup().name
param publisherEmail string = 'admin@travelagent.com'
param publisherName string = 'Travel Agent Bot'
param apimSku string = 'Developer'

param serverfarmsName string = resourceBaseName
param webAppName string = resourceBaseName
param identityName string = resourceBaseName
param location string = resourceGroup().location

resource identity 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' = {
  location: location
  name: identityName
}

// Reference existing Azure OpenAI resource
resource openAIAccount 'Microsoft.CognitiveServices/accounts@2023-05-01' existing = {
  name: azureOpenAIResourceName
  scope: resourceGroup(azureOpenAIResourceGroup)
}

// Role assignment: Grant Managed Identity access to Azure OpenAI
resource openAIRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(identity.id, openAIAccount.id, 'Cognitive Services OpenAI User')
  scope: openAIAccount
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '5e0bd9bd-7b93-4f28-af87-19fc36ad61bd') // Cognitive Services OpenAI User
    principalId: identity.properties.principalId
    principalType: 'ServicePrincipal'
  }
}

// Deploy VNet and Networking Infrastructure
module networking './networking.bicep' = if (deployVNet) {
  name: 'networking-deployment'
  params: {
    resourceBaseName: resourceBaseName
    location: location
    azureOpenAIResourceName: azureOpenAIResourceName
    azureOpenAIResourceGroup: azureOpenAIResourceGroup
  }
}

// Compute resources for your Web App
resource serverfarm 'Microsoft.Web/serverfarms@2021-02-01' = if (deployAppService) {
  kind: 'app'
  location: location
  name: serverfarmsName
  sku: {
    name: webAppSKU
  }
}

// Web App that hosts your bot
resource webApp 'Microsoft.Web/sites@2021-02-01' = if (deployAppService) {
  kind: 'app'
  location: location
  name: webAppName
  properties: {
    serverFarmId: serverfarm.id
    httpsOnly: true
    virtualNetworkSubnetId: deployVNet ? networking.outputs.appServiceSubnetId : null
    publicNetworkAccess: deployVNet ? 'Disabled' : 'Enabled'
    siteConfig: {
      alwaysOn: true
      netFrameworkVersion: 'v9.0'
      vnetRouteAllEnabled: deployVNet
      http20Enabled: true
      minTlsVersion: '1.2'
      ftpsState: 'Disabled'
      appSettings: [
        {
          name: 'WEBSITE_RUN_FROM_PACKAGE'
          value: '1'
        }
        {
          name: 'RUNNING_ON_AZURE'
          value: '1'
        }
        {
          name: 'Connections__BotServiceConnection__Settings__ClientId'
          value: identity.properties.clientId
        }
        {
          name: 'Connections__BotServiceConnection__Settings__TenantId'
          value: identity.properties.tenantId
        }
        {
          name: 'TokenValidation__Audiences__0'
          value: identity.properties.clientId
        }
        {
          name: 'Azure__OpenAIEndpoint'
          value: azureOpenAIEndpoint
        }
        {
          name: 'Azure__OpenAIDeploymentName'
          value: azureOpenAIDeploymentName
        }
        {
          name: 'Azure__UseManagedIdentity'
          value: useManagedIdentity
        }
        {
          name: 'Azure__ManagedIdentityClientId'
          value: identity.properties.clientId
        }
        {
          name: 'AZURE_CLIENT_ID'
          value: identity.properties.clientId
        }
        {
          name: 'WEBSITE_VNET_ROUTE_ALL'
          value: deployVNet ? '1' : '0'
        }
        {
          name: 'WEBSITE_DNS_SERVER'
          value: '168.63.129.16'
        }
      ]
    }
  }
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${identity.id}': {}
    }
  }
  dependsOn: [
    networking
  ]
}

// App Service Access Restrictions - Allow only APIM traffic
resource webAppConfig 'Microsoft.Web/sites/config@2022-03-01' = if (deployAppService && deployVNet) {
  parent: webApp
  name: 'web'
  properties: {
    ipSecurityRestrictions: [
      {
        name: 'Allow-APIM-Subnet'
        action: 'Allow'
        priority: 200
        vnetSubnetResourceId: networking.outputs.apimSubnetId
        description: 'Allow traffic from APIM subnet (internal VNet routing)'
      }
      {
        name: 'Allow-APIM-PublicIP'
        action: 'Allow'
        priority: 201
        ipAddress: '${apim.outputs.apimPublicIP}/32'
        description: 'Allow traffic from APIM public IP (external routing)'
      }
      {
        name: 'Deny-All'
        action: 'Deny'
        priority: 2147483647
        ipAddress: 'Any'
        description: 'Deny all other traffic - App Service accessible only via APIM'
      }
    ]
    scmIpSecurityRestrictions: [
      {
        name: 'Allow-All-SCM'
        action: 'Allow'
        priority: 100
        ipAddress: 'Any'
        description: 'Allow deployment from any IP (SCM site for Kudu/deployments)'
      }
    ]
    scmIpSecurityRestrictionsUseMain: false
  }
  dependsOn: [
    apim
  ]
}

// Deploy APIM as reverse proxy
module apim './apim.bicep' = if (deployVNet && deployAppService) {
  name: 'apim-deployment'
  params: {
    resourceBaseName: resourceBaseName
    location: location
    apimSubnetId: networking.outputs.apimSubnetId
    backendBotUrl: 'https://${webApp.properties.defaultHostName}'
    publisherEmail: publisherEmail
    publisherName: publisherName
    apimSku: apimSku
    managedIdentityClientId: identity.properties.clientId
    managedIdentityResourceId: identity.id
  }
  dependsOn: [
    networking
    webApp
  ]
}

// Register your web service as a bot with the Bot Framework
module azureBotRegistration './botRegistration/azurebot.bicep' = {
  name: 'Azure-Bot-registration'
  params: {
    deployAppService: deployAppService
    resourceBaseName: resourceBaseName
    identityClientId: identity.properties.clientId
    identityResourceId: identity.id
    identityTenantId: identity.properties.tenantId
    // Use APIM endpoint if VNet is deployed, otherwise use App Service directly
    botAppDomain: deployVNet && deployAppService ? replace(apim.outputs.apimFQDN, 'https://', '') : (deployAppService ? webApp.properties.defaultHostName : botDomain)
    botDisplayName: botDisplayName
    botConnectionClientId: aadAppClientId
    botConnectionClientSecret: aadAppClientSecret
    botConnectionTenantId: aadAppTenantId
  }
}

// The output will be persisted in .env.{envName}. Visit https://aka.ms/teamsfx-actions/arm-deploy for more details.
output BOT_AZURE_APP_SERVICE_RESOURCE_ID string = deployAppService ? webApp.id : ''
output BOT_DOMAIN string = deployVNet && deployAppService ? replace(apim.outputs.apimFQDN, 'https://', '') : (deployAppService ? webApp.properties.defaultHostName : botDomain)
output BOT_ID string = deployAppService ? identity.properties.clientId :aadAppClientId
output BOT_TENANT_ID string = identity.properties.tenantId
output APIM_GATEWAY_URL string = deployVNet && deployAppService ? apim.outputs.apimGatewayUrl : ''
output APIM_PUBLIC_IP string = deployVNet && deployAppService ? apim.outputs.apimPublicIP : ''
output BOT_MESSAGES_ENDPOINT string = deployVNet && deployAppService ? apim.outputs.botMessagesEndpoint : ''
output VNET_ID string = deployVNet ? networking.outputs.vnetId : ''
// output BOT_SERVICE_PRIVATE_ENDPOINT_ID string = deployVNet ? botServicePrivateEndpoint.outputs.botServicePrivateEndpointId : ''
// ?? DISABLED: Bot Service Private Endpoint not used for Teams channels
