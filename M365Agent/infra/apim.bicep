// Azure API Management (APIM) in External VNet Mode
// Provides public endpoint for Teams Bot while securing backend in private VNet

@description('Base name for resources')
param resourceBaseName string

@description('Location for all resources')
param location string = resourceGroup().location

@description('APIM subnet ID')
param apimSubnetId string

@description('App Service backend URL (internal)')
param backendBotUrl string

@description('Publisher email for APIM')
param publisherEmail string

@description('Publisher name/organization')
param publisherName string

@description('APIM SKU')
@allowed([
  'Developer'
  'Premium'
  'Standard'
])
param apimSku string = 'Developer'

@description('APIM capacity')
param apimCapacity int = 1

@description('Custom domain name for APIM (optional)')
param customDomainName string = ''

@description('Managed Identity Client ID for backend auth')
param managedIdentityClientId string

@description('Managed Identity Resource ID for APIM')
param managedIdentityResourceId string

// Public IP for APIM
resource apimPublicIP 'Microsoft.Network/publicIPAddresses@2023-05-01' = {
  name: '${resourceBaseName}-apim-pip'
  location: location
  sku: {
    name: 'Standard'
  }
  properties: {
    publicIPAllocationMethod: 'Static'
    dnsSettings: {
      domainNameLabel: '${resourceBaseName}-apim'
    }
  }
}

// API Management Service
resource apim 'Microsoft.ApiManagement/service@2023-05-01-preview' = {
  name: '${resourceBaseName}-apim'
  location: location
  sku: {
    name: apimSku
    capacity: apimCapacity
  }
  properties: {
    publisherEmail: publisherEmail
    publisherName: publisherName
    virtualNetworkType: 'External'
    virtualNetworkConfiguration: {
      subnetResourceId: apimSubnetId
    }
    publicIpAddressId: apimPublicIP.id
    customProperties: {
      'Microsoft.WindowsAzure.ApiManagement.Gateway.Security.Protocols.Tls11': 'false'
      'Microsoft.WindowsAzure.ApiManagement.Gateway.Security.Protocols.Tls10': 'false'
      'Microsoft.WindowsAzure.ApiManagement.Gateway.Security.Protocols.Ssl30': 'false'
      'Microsoft.WindowsAzure.ApiManagement.Gateway.Security.Backend.Protocols.Tls11': 'false'
      'Microsoft.WindowsAzure.ApiManagement.Gateway.Security.Backend.Protocols.Tls10': 'false'
      'Microsoft.WindowsAzure.ApiManagement.Gateway.Security.Backend.Protocols.Ssl30': 'false'
      'Microsoft.WindowsAzure.ApiManagement.Gateway.Protocols.Server.Http2': 'true'
    }
  }
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${managedIdentityResourceId}': {}
    }
  }
}

// Backend for the Bot App Service
resource botBackend 'Microsoft.ApiManagement/service/backends@2023-05-01-preview' = {
  parent: apim
  name: 'travel-agent-bot-backend'
  properties: {
    description: 'Travel Agent Bot App Service Backend'
    url: backendBotUrl
    protocol: 'http'
    tls: {
      validateCertificateChain: true
      validateCertificateName: true
    }
    credentials: {
      header: {
        'X-Managed-Identity-ClientId': [
          managedIdentityClientId
        ]
      }
    }
  }
}

// API for Bot Messages Endpoint
resource botApi 'Microsoft.ApiManagement/service/apis@2023-05-01-preview' = {
  parent: apim
  name: 'travel-agent-bot-api'
  properties: {
    displayName: 'Travel Agent Bot API'
    description: 'API for Microsoft Teams Travel Agent Bot'
    path: ''
    protocols: [
      'https'
    ]
    subscriptionRequired: false
    isCurrent: true
    serviceUrl: backendBotUrl
  }
}

// Operation: POST /api/messages
resource botMessagesOperation 'Microsoft.ApiManagement/service/apis/operations@2023-05-01-preview' = {
  parent: botApi
  name: 'post-messages'
  properties: {
    displayName: 'Post Messages'
    method: 'POST'
    urlTemplate: '/api/messages'
    description: 'Receives messages from Microsoft Teams via Bot Framework'
    request: {
      headers: [
        {
          name: 'Authorization'
          description: 'Bot Framework JWT token'
          type: 'string'
          required: true
        }
      ]
    }
    responses: [
      {
        statusCode: 200
        description: 'Success'
      }
      {
        statusCode: 401
        description: 'Unauthorized'
      }
      {
        statusCode: 500
        description: 'Internal Server Error'
      }
    ]
  }
}

// Policy for Bot Messages Operation
resource botMessagesPolicy 'Microsoft.ApiManagement/service/apis/operations/policies@2023-05-01-preview' = {
  parent: botMessagesOperation
  name: 'policy'
  properties: {
    value: format('''
<policies>
  <inbound>
    <base />
    <!-- Validate JWT token from Bot Framework -->
    <validate-jwt header-name="Authorization" 
                  failed-validation-httpcode="401" 
                  failed-validation-error-message="Unauthorized. Invalid or missing Bot Framework token."
                  require-expiration-time="true"
                  require-scheme="Bearer"
                  require-signed-tokens="true">
      <openid-config url="https://login.botframework.com/v1/.well-known/openidconfiguration" />
      <audiences>
        <audience>{0}</audience>
        <audience>https://{1}-apim.azure-api.net</audience>
        <audience>https://api.botframework.com</audience>
      </audiences>
      <issuers>
        <issuer>https://api.botframework.com</issuer>
      </issuers>
    </validate-jwt>
    
    <!-- Rate limiting: 100 calls per minute per client -->
    <rate-limit-by-key calls="100" renewal-period="60" counter-key="@(context.Request.IpAddress)" />
    
    <!-- Set backend service -->
    <set-backend-service backend-id="travel-agent-bot-backend" />
    
    <!-- Forward all headers -->
    <set-header name="X-Forwarded-For" exists-action="override">
      <value>@(context.Request.IpAddress)</value>
    </set-header>
    <set-header name="X-Forwarded-Proto" exists-action="override">
      <value>https</value>
    </set-header>
  </inbound>
  <backend>
    <base />
  </backend>
  <outbound>
    <base />
    <!-- Add security headers -->
    <set-header name="X-Content-Type-Options" exists-action="override">
      <value>nosniff</value>
    </set-header>
    <set-header name="X-Frame-Options" exists-action="override">
      <value>DENY</value>
    </set-header>
    <set-header name="Strict-Transport-Security" exists-action="override">
      <value>max-age=31536000; includeSubDomains</value>
    </set-header>
  </outbound>
  <on-error>
    <base />
  </on-error>
</policies>
''', managedIdentityClientId, resourceBaseName)
    format: 'xml'
  }
}

// Global API Policy (applies to all APIs)
resource globalPolicy 'Microsoft.ApiManagement/service/policies@2023-05-01-preview' = {
  parent: apim
  name: 'policy'
  properties: {
    value: '''
<policies>
  <inbound>
    <!-- CORS policy for development/testing -->
    <cors allow-credentials="false">
      <allowed-origins>
        <origin>https://teams.microsoft.com</origin>
      </allowed-origins>
      <allowed-methods>
        <method>POST</method>
        <method>GET</method>
      </allowed-methods>
      <allowed-headers>
        <header>*</header>
      </allowed-headers>
    </cors>
  </inbound>
  <backend>
    <forward-request />
  </backend>
  <outbound />
  <on-error />
</policies>
'''
    format: 'xml'
  }
}

// Note: Diagnostic Settings for Application Insights can be added after creating an Application Insights logger
// To enable, first create an Application Insights resource and logger, then uncomment the resource below
/*
resource apimDiagnostics 'Microsoft.ApiManagement/service/diagnostics@2023-05-01-preview' = {
  parent: apim
  name: 'applicationinsights'
  properties: {
    alwaysLog: 'allErrors'
    loggerId: '/subscriptions/${subscription().subscriptionId}/resourceGroups/${resourceGroup().name}/providers/Microsoft.ApiManagement/service/${apim.name}/loggers/applicationinsights'
    sampling: {
      samplingType: 'fixed'
      percentage: 100
    }
    frontend: {
      request: {
        headers: [
          'Authorization'
        ]
        body: {
          bytes: 1024
        }
      }
      response: {
        headers: []
        body: {
          bytes: 1024
        }
      }
    }
    backend: {
      request: {
        headers: []
        body: {
          bytes: 1024
        }
      }
      response: {
        headers: []
        body: {
          bytes: 1024
        }
      }
    }
  }
}
*/

// Outputs
output apimId string = apim.id
output apimName string = apim.name
output apimGatewayUrl string = apim.properties.gatewayUrl
output apimPublicIP string = apimPublicIP.properties.ipAddress
output apimFQDN string = apimPublicIP.properties.dnsSettings.fqdn
output apimManagedIdentityPrincipalId string = managedIdentityClientId
output botMessagesEndpoint string = '${apim.properties.gatewayUrl}/api/messages'
