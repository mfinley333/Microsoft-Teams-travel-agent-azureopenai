# Teams Bot Reference Architecture - Secure VNet with APIM Gateway

## ?? Executive Summary

This document describes the complete Azure infrastructure architecture for a Microsoft Teams bot that leverages Azure OpenAI, deployed in a secure Virtual Network (VNet) with Azure API Management (APIM) as a reverse proxy gateway.

**Architecture Highlights:**
- ? Enterprise-grade security with defense-in-depth
- ? Private networking with VNet isolation
- ? Public APIM gateway for Bot Framework connectivity
- ? Private App Service backend
- ? Managed Identity authentication (no credentials)
- ? Infrastructure as Code (Bicep)

---

## ??? High-Level Architecture

```
???????????????????????????????????????????????????????????????????
?                        INTERNET                                  ?
?  ????????????????????         ??????????????????               ?
?  ? Microsoft Teams  ??????????? Bot Framework  ?               ?
?  ?     Client       ?         ?    Service     ?               ?
?  ????????????????????         ??????????????????               ?
???????????????????????????????????????????????????????????????????
                                           ?
                                           ? HTTPS + JWT
                                           ?
???????????????????????????????????????????????????????????????????
?                    AZURE SUBSCRIPTION                            ?
?                                                                  ?
?  ?????????????????????????????????????????????????????????????? ?
?  ? Azure Bot Service (Global, Public)                         ? ?
?  ? Name: bot220214                                            ? ?
?  ? Endpoint: https://bot220214-apim.azure-api.net/api/messages? ?
?  ? App ID: 704c5df5-0b49-4a0f-accc-94e52ef13c58              ? ?
?  ? Type: UserAssignedMSI                                      ? ?
?  ?????????????????????????????????????????????????????????????? ?
?                               ?                                  ?
?                               ? Routes messages to endpoint      ?
?                               ?                                  ?
?  ?????????????????????????????????????????????????????????????? ?
?  ? APIM (External VNet Mode)                                  ? ?
?  ? Name: bot220214-apim                                       ? ?
?  ? Public IP: 135.116.200.37                                  ? ?
?  ? Gateway: https://bot220214-apim.azure-api.net              ? ?
?  ? ?????????????????????????????????????????????????????????? ? ?
?  ? ? Security: JWT Validation, Rate Limiting, NSG Rules     ? ? ?
?  ? ?????????????????????????????????????????????????????????? ? ?
?  ?????????????????????????????????????????????????????????????? ?
?                               ?                                  ?
?                               ? Forwards to backend              ?
?                               ?                                  ?
?  ?????????????????????????????????????????????????????????????? ?
?  ? Virtual Network: bot220214-vnet (10.0.0.0/16)              ? ?
?  ? ???????????????????????????????????????????????????????????? ?
?  ? ? Subnet: apim-subnet (10.0.2.0/24)                        ? ?
?  ? ? - APIM External mode deployment                          ? ?
?  ? ? - NSG: Allow HTTPS inbound                               ? ?
?  ? ???????????????????????????????????????????????????????????? ?
?  ? ???????????????????????????????????????????????????????????? ?
?  ? ? Subnet: appservice-subnet (10.0.1.0/24)                  ? ?
?  ? ? ???????????????????????????????????????????????????????? ? ?
?  ? ? ? App Service: bot220214                               ? ? ?
?  ? ? ? Runtime: .NET 9.0                                    ? ? ?
?  ? ? ? VNet Integration: Enabled                            ? ? ?
?  ? ? ? Public Access: Disabled                              ? ? ?
?  ? ? ? Access Restrictions: APIM Only                       ? ? ?
?  ? ? ? Identity: User-Assigned MI (bot220214)               ? ? ?
?  ? ? ???????????????????????????????????????????????????????? ? ?
?  ? ? - Delegation: Microsoft.Web/serverFarms                  ? ?
?  ? ???????????????????????????????????????????????????????????? ?
?  ? ???????????????????????????????????????????????????????????? ?
?  ? ? Subnet: privateendpoints-subnet (10.0.3.0/24)            ? ?
?  ? ? ???????????????????????????????????????????????????????? ? ?
?  ? ? ? Private Endpoint: Azure OpenAI                       ? ? ?
?  ? ? ? Private IP: 10.0.3.4                                 ? ? ?
?  ? ? ? Private DNS Zone: privatelink.openai.azure.com       ? ? ?
?  ? ? ???????????????????????????????????????????????????????? ? ?
?  ? ???????????????????????????????????????????????????????????? ?
?  ?????????????????????????????????????????????????????????????? ?
?                               ?                                  ?
?                               ? Managed Identity Auth            ?
?                               ?                                  ?
?  ?????????????????????????????????????????????????????????????? ?
?  ? Azure OpenAI (Azure AI Foundry)                            ? ?
?  ? Name: aif-travelagent-bot                                  ? ?
?  ? Model: gpt-4 (Deployment: gpt-4.1)                         ? ?
?  ? Network: Private Endpoint Only                             ? ?
?  ? Auth: Managed Identity (bot220214)                         ? ?
?  ? Role: Cognitive Services OpenAI User                       ? ?
?  ?????????????????????????????????????????????????????????????? ?
?                                                                  ?
?  ?????????????????????????????????????????????????????????????? ?
?  ? Managed Identity: bot220214                                ? ?
?  ? Client ID: 704c5df5-0b49-4a0f-accc-94e52ef13c58           ? ?
?  ? Type: User-Assigned                                        ? ?
?  ? Used By: App Service, APIM, Bot Service                    ? ?
?  ? RBAC Role: Cognitive Services OpenAI User                  ? ?
?  ?????????????????????????????????????????????????????????????? ?
????????????????????????????????????????????????????????????????????
```

---

## ?? Azure Components Detailed

### 1. Azure Bot Service

**Purpose:** Bot Framework registration and channel management

**Resource Type:** `Microsoft.BotService/botServices`

**Configuration:**
```bicep
resource botService 'Microsoft.BotService/botServices@2021-03-01' = {
  kind: 'azurebot'
  location: 'global'
  name: 'bot220214'
  properties: {
    displayName: 'Travel Agent Bot'
    endpoint: 'https://bot220214-apim.azure-api.net/api/messages'
    msaAppId: '704c5df5-0b49-4a0f-accc-94e52ef13c58'
    msaAppMSIResourceId: '/subscriptions/.../bot220214'
    msaAppTenantId: '{tenantId}'
    msaAppType: 'UserAssignedMSI'
  }
  sku: {
    name: 'F0'  // Free tier
  }
}
```

**Key Properties:**
- ? **Global resource** (no specific region)
- ? **Public endpoint** (required for Bot Framework Service)
- ? **Points to APIM gateway** (not directly to App Service)
- ? **User-Assigned Managed Identity** authentication
- ? **Teams channel** enabled for Microsoft Teams integration

**Channel Configuration:**
```bicep
resource botServiceMsTeamsChannel 'Microsoft.BotService/botServices/channels@2021-03-01' = {
  parent: botService
  location: 'global'
  name: 'MsTeamsChannel'
  properties: {
    channelName: 'MsTeamsChannel'
  }
}
```

**OAuth Connection (Optional - for Microsoft Graph):**
```bicep
resource botServiceOAuthConnection 'Microsoft.BotService/botServices/Connections@2021-03-01' = {
  parent: botService
  name: 'GraphConnection'
  properties: {
    clientId: '{aadAppClientId}'
    clientSecret: '{aadAppClientSecret}'
    scopes: 'User.Read Files.Read Calendars.Read'  // Delegated permissions
    serviceProviderDisplayName: 'Azure Active Directory v2'
    serviceProviderId: '30dd229c-58e3-4a48-bdfd-91ec48eb906c'
  }
}
```

**Critical Notes:**
- ? **Do NOT add Private Endpoint** to Bot Service - breaks Teams channel communication
- ? Bot Service must be publicly accessible for Bot Framework Service
- ? Private Endpoints only work for DirectLine Speech/WebChat scenarios

---

### 2. Azure API Management (APIM)

**Purpose:** Reverse proxy, security gateway, and public endpoint for Bot Framework

**Resource Type:** `Microsoft.ApiManagement/service`

**Configuration:**
```bicep
resource apim 'Microsoft.ApiManagement/service@2023-05-01-preview' = {
  name: 'bot220214-apim'
  location: 'swedencentral'
  sku: {
    name: 'Developer'  // or 'Standard' or 'Premium'
    capacity: 1
  }
  properties: {
    publisherEmail: 'admin@example.com'
    publisherName: 'Organization'
    virtualNetworkType: 'External'  // Critical: External mode
    virtualNetworkConfiguration: {
      subnetResourceId: '{apimSubnetId}'
    }
    publicIpAddressId: '{apimPublicIPId}'
  }
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '{managedIdentityId}': {}
    }
  }
}
```

**VNet Mode:** `External`
- ? APIM has public IP (135.116.200.37)
- ? Gateway accessible from internet
- ? Management endpoints accessible
- ? Can route to private VNet resources

**Security Features:**

1. **JWT Token Validation:**
```xml
<validate-jwt header-name="Authorization" 
              failed-validation-httpcode="401"
              require-expiration-time="true"
              require-scheme="Bearer">
  <openid-config url="https://login.botframework.com/v1/.well-known/openidconfiguration" />
  <audiences>
    <audience>704c5df5-0b49-4a0f-accc-94e52ef13c58</audience>
    <audience>https://bot220214-apim.azure-api.net</audience>
    <audience>https://api.botframework.com</audience>
  </audiences>
  <issuers>
    <issuer>https://api.botframework.com</issuer>
  </issuers>
</validate-jwt>
```

2. **Rate Limiting:**
```xml
<rate-limit-by-key calls="100" 
                   renewal-period="60" 
                   counter-key="@(context.Request.IpAddress)" />
```

3. **Security Headers:**
```xml
<set-header name="X-Content-Type-Options" exists-action="override">
  <value>nosniff</value>
</set-header>
<set-header name="Strict-Transport-Security" exists-action="override">
  <value>max-age=31536000; includeSubDomains</value>
</set-header>
```

**Backend Configuration:**
```bicep
resource botBackend 'Microsoft.ApiManagement/service/backends@2023-05-01-preview' = {
  parent: apim
  name: 'travel-agent-bot-backend'
  properties: {
    url: 'https://bot220214.azurewebsites.net'  // App Service URL
    protocol: 'http'
    tls: {
      validateCertificateChain: true
      validateCertificateName: true
    }
  }
}
```

**API Definition:**
```bicep
resource botApi 'Microsoft.ApiManagement/service/apis@2023-05-01-preview' = {
  parent: apim
  name: 'travel-agent-bot-api'
  properties: {
    displayName: 'Travel Agent Bot API'
    path: ''  // Root path
    protocols: ['https']
    subscriptionRequired: false
    serviceUrl: 'https://bot220214.azurewebsites.net'
  }
}
```

**Critical Operations:**
```bicep
resource botMessagesOperation 'Microsoft.ApiManagement/service/apis/operations@2023-05-01-preview' = {
  parent: botApi
  name: 'post-messages'
  properties: {
    method: 'POST'
    urlTemplate: '/api/messages'  // Bot Framework endpoint
  }
}
```

**Public IP Address:**
```bicep
resource apimPublicIP 'Microsoft.Network/publicIPAddresses@2023-05-01' = {
  name: 'bot220214-apim-pip'
  location: 'swedencentral'
  sku: {
    name: 'Standard'
  }
  properties: {
    publicIPAllocationMethod: 'Static'
    dnsSettings: {
      domainNameLabel: 'bot220214-apim'
    }
  }
}
```

**Gateway URL:** `https://bot220214-apim.azure-api.net`

---

### 3. Virtual Network (VNet)

**Purpose:** Network isolation and secure communication

**Resource Type:** `Microsoft.Network/virtualNetworks`

**Configuration:**
```bicep
resource vnet 'Microsoft.Network/virtualNetworks@2023-05-01' = {
  name: 'bot220214-vnet'
  location: 'swedencentral'
  properties: {
    addressSpace: {
      addressPrefixes: ['10.0.0.0/16']
    }
    subnets: [
      {
        name: 'apim-subnet'
        properties: {
          addressPrefix: '10.0.2.0/24'
          networkSecurityGroup: {
            id: apimNsg.id
          }
        }
      }
      {
        name: 'appservice-subnet'
        properties: {
          addressPrefix: '10.0.1.0/24'
          delegations: [
            {
              name: 'delegation'
              properties: {
                serviceName: 'Microsoft.Web/serverFarms'
              }
            }
          ]
          networkSecurityGroup: {
            id: appServiceNsg.id
          }
        }
      }
      {
        name: 'privateendpoints-subnet'
        properties: {
          addressPrefix: '10.0.3.0/24'
          privateEndpointNetworkPolicies: 'Disabled'
        }
      }
    ]
  }
}
```

**Subnet Details:**

| Subnet | CIDR | Purpose | Delegation | NSG |
|--------|------|---------|------------|-----|
| apim-subnet | 10.0.2.0/24 | APIM deployment | None | apim-nsg |
| appservice-subnet | 10.0.1.0/24 | App Service VNet integration | Microsoft.Web/serverFarms | appservice-nsg |
| privateendpoints-subnet | 10.0.3.0/24 | Private Endpoints (OpenAI) | None | None |

---

### 4. Network Security Groups (NSGs)

**Purpose:** Network-level access control

#### APIM NSG

```bicep
resource apimNsg 'Microsoft.Network/networkSecurityGroups@2023-05-01' = {
  name: 'bot220214-apim-nsg'
  location: 'swedencentral'
  properties: {
    securityRules: [
      {
        name: 'AllowHTTPSInbound'
        properties: {
          priority: 100
          direction: 'Inbound'
          access: 'Allow'
          protocol: 'Tcp'
          sourceAddressPrefix: 'Internet'
          sourcePortRange: '*'
          destinationAddressPrefix: '*'
          destinationPortRange: '443'
        }
      }
      {
        name: 'AllowAPIMManagement'
        properties: {
          priority: 110
          direction: 'Inbound'
          access: 'Allow'
          protocol: 'Tcp'
          sourceAddressPrefix: 'ApiManagement'
          sourcePortRange: '*'
          destinationAddressPrefix: 'VirtualNetwork'
          destinationPortRange: '3443'
        }
      }
      {
        name: 'AllowAzureLoadBalancer'
        properties: {
          priority: 120
          direction: 'Inbound'
          access: 'Allow'
          protocol: '*'
          sourceAddressPrefix: 'AzureLoadBalancer'
          sourcePortRange: '*'
          destinationAddressPrefix: '*'
          destinationPortRange: '*'
        }
      }
    ]
  }
}
```

#### App Service NSG

```bicep
resource appServiceNsg 'Microsoft.Network/networkSecurityGroups@2023-05-01' = {
  name: 'bot220214-appservice-nsg'
  location: 'swedencentral'
  properties: {
    securityRules: [
      {
        name: 'AllowAPIMSubnet'
        properties: {
          priority: 100
          direction: 'Inbound'
          access: 'Allow'
          protocol: 'Tcp'
          sourceAddressPrefix: '10.0.2.0/24'  // APIM subnet
          sourcePortRange: '*'
          destinationAddressPrefix: '*'
          destinationPortRange: '443'
        }
      }
      {
        name: 'DenyAllOthers'
        properties: {
          priority: 200
          direction: 'Inbound'
          access: 'Deny'
          protocol: '*'
          sourceAddressPrefix: '*'
          sourcePortRange: '*'
          destinationAddressPrefix: '*'
          destinationPortRange: '*'
        }
      }
    ]
  }
}
```

---

### 5. App Service

**Purpose:** Host bot application code (.NET 9)

**Resource Type:** `Microsoft.Web/sites`

**Configuration:**
```bicep
resource webApp 'Microsoft.Web/sites@2021-02-01' = {
  name: 'bot220214'
  location: 'swedencentral'
  kind: 'app'
  properties: {
    serverFarmId: serverfarm.id
    httpsOnly: true
    publicNetworkAccess: 'Disabled'  // No public endpoint
    virtualNetworkSubnetId: appServiceSubnetId
    siteConfig: {
      alwaysOn: true
      netFrameworkVersion: 'v9.0'
      vnetRouteAllEnabled: true
      http20Enabled: true
      minTlsVersion: '1.2'
      ftpsState: 'Disabled'
      appSettings: [
        {
          name: 'Connections__BotServiceConnection__Settings__ClientId'
          value: '704c5df5-0b49-4a0f-accc-94e52ef13c58'
        }
        {
          name: 'Azure__OpenAIEndpoint'
          value: 'https://aif-travelagent-bot.openai.azure.com/'
        }
        {
          name: 'Azure__OpenAIDeploymentName'
          value: 'gpt-4.1'
        }
        {
          name: 'Azure__UseManagedIdentity'
          value: 'true'
        }
        {
          name: 'AZURE_CLIENT_ID'
          value: '704c5df5-0b49-4a0f-accc-94e52ef13c58'
        }
      ]
    }
  }
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '/subscriptions/.../bot220214': {}
    }
  }
}
```

**App Service Plan:**
```bicep
resource serverfarm 'Microsoft.Web/serverfarms@2021-02-01' = {
  name: 'bot220214'
  location: 'swedencentral'
  kind: 'app'
  sku: {
    name: 'B1'  // Basic tier (minimum for VNet integration)
  }
}
```

**Access Restrictions:**
```bicep
resource webAppConfig 'Microsoft.Web/sites/config@2022-03-01' = {
  parent: webApp
  name: 'web'
  properties: {
    ipSecurityRestrictions: [
      {
        name: 'Allow-APIM-Subnet'
        action: 'Allow'
        priority: 200
        vnetSubnetResourceId: apimSubnetId
        description: 'Allow APIM subnet (internal VNet routing)'
      }
      {
        name: 'Allow-APIM-PublicIP'
        action: 'Allow'
        priority: 201
        ipAddress: '135.116.200.37/32'
        description: 'Allow APIM public IP (external routing)'
      }
      {
        name: 'Deny-All'
        action: 'Deny'
        priority: 2147483647
        ipAddress: 'Any'
        description: 'Deny all other traffic'
      }
    ]
    scmIpSecurityRestrictions: [
      {
        name: 'Allow-All-SCM'
        action: 'Allow'
        priority: 100
        ipAddress: 'Any'
        description: 'Allow deployments from anywhere'
      }
    ]
    scmIpSecurityRestrictionsUseMain: false
  }
}
```

**Key Features:**
- ? VNet integrated (private networking)
- ? No public endpoint (`publicNetworkAccess: 'Disabled'`)
- ? Access restrictions (APIM only)
- ? User-Assigned Managed Identity
- ? .NET 9.0 runtime
- ? Always On enabled

---

### 6. Azure OpenAI (AI Foundry)

**Purpose:** GPT-4 model hosting and inference

**Resource Type:** `Microsoft.CognitiveServices/accounts`

**Configuration:**
```bicep
resource openai 'Microsoft.CognitiveServices/accounts@2023-05-01' existing = {
  name: 'aif-travelagent-bot'
  scope: resourceGroup('rg-travelagent-bot-5555')
}
```

**Model Deployment:**
- Model: `gpt-4`
- Deployment Name: `gpt-4.1`
- Endpoint: `https://aif-travelagent-bot.openai.azure.com/`

**Network Configuration:**
- ? Private Endpoint in `privateendpoints-subnet`
- ? Private IP: `10.0.3.4`
- ? Public network access: Disabled
- ? DNS: `privatelink.openai.azure.com`

**Authentication:**
- ? Managed Identity only (no API keys)
- ? RBAC: `Cognitive Services OpenAI User`
- ? Identity: `bot220214` (User-Assigned MI)

---

### 7. Managed Identity

**Purpose:** Credential-free authentication

**Resource Type:** `Microsoft.ManagedIdentity/userAssignedIdentities`

**Configuration:**
```bicep
resource identity 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' = {
  name: 'bot220214'
  location: 'swedencentral'
}
```

**Properties:**
- Client ID: `704c5df5-0b49-4a0f-accc-94e52ef13c58`
- Principal ID: `3edd4268-ffb1-4e61-b62c-fdb93a8f17d6`
- Tenant ID: `{tenantId}`

**Used By:**
- ? App Service (for Azure OpenAI authentication)
- ? APIM (shared identity)
- ? Bot Service (authentication mechanism)

**RBAC Role Assignment:**
```bicep
resource openAIRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(identity.id, openai.id, 'Cognitive Services OpenAI User')
  scope: openai
  properties: {
    roleDefinitionId: subscriptionResourceId(
      'Microsoft.Authorization/roleDefinitions',
      '5e0bd9bd-7b93-4f28-af87-19fc36ad61bd'  // Cognitive Services OpenAI User
    )
    principalId: identity.properties.principalId
    principalType: 'ServicePrincipal'
  }
}
```

---

### 8. Private Endpoint & DNS

**Purpose:** Secure Azure OpenAI access

**Private Endpoint:**
```bicep
resource openaiPrivateEndpoint 'Microsoft.Network/privateEndpoints@2023-05-01' = {
  name: 'bot220214-openai-pe'
  location: 'swedencentral'
  properties: {
    subnet: {
      id: privateEndpointsSubnetId
    }
    privateLinkServiceConnections: [
      {
        name: 'openai-connection'
        properties: {
          privateLinkServiceId: openai.id
          groupIds: ['account']
        }
      }
    ]
  }
}
```

**Private DNS Zone:**
```bicep
resource privateDnsZone 'Microsoft.Network/privateDnsZones@2020-06-01' = {
  name: 'privatelink.openai.azure.com'
  location: 'global'
}

resource privateDnsZoneLink 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2020-06-01' = {
  parent: privateDnsZone
  name: 'vnet-link'
  location: 'global'
  properties: {
    virtualNetwork: {
      id: vnet.id
    }
    registrationEnabled: false
  }
}

resource privateDnsZoneGroup 'Microsoft.Network/privateEndpoints/privateDnsZoneGroups@2023-05-01' = {
  parent: openaiPrivateEndpoint
  name: 'default'
  properties: {
    privateDnsZoneConfigs: [
      {
        name: 'openai-config'
        properties: {
          privateDnsZoneId: privateDnsZone.id
        }
      }
    ]
  }
}
```

**DNS Resolution:**
```
aif-travelagent-bot.openai.azure.com
    ? CNAME
aif-travelagent-bot.privatelink.openai.azure.com
    ? A record (Private DNS Zone)
10.0.3.4 (Private IP in VNet)
```

---

## ?? Security Architecture

### Defense-in-Depth Layers

**Layer 1: Bot Framework Authentication**
```
Bot Framework Service
    ? Generates JWT token
    ? iss: https://api.botframework.com
    ? aud: 704c5df5-0b49-4a0f-accc-94e52ef13c58
APIM validates JWT
    ? Issuer check
    ? Audience check (3 audiences)
    ? Expiration check
    ? Signature verification
```

**Layer 2: APIM Gateway Security**
```
APIM (bot220214-apim)
    ?? JWT validation ?
    ?? Rate limiting (100 req/min) ?
    ?? NSG rules (HTTPS only) ?
    ?? TLS 1.2+ only ?
    ?? Security headers ?
```

**Layer 3: App Service Access Restrictions**
```
App Service (bot220214)
    ?? IP allowlist ?
    ?  ?? APIM subnet: 10.0.2.0/24
    ?  ?? APIM public IP: 135.116.200.37
    ?? Default deny all ?
    ?? VNet integrated ?
```

**Layer 4: Network Isolation**
```
VNet (10.0.0.0/16)
    ?? App Service: Private (no public endpoint) ?
    ?? Azure OpenAI: Private endpoint only ?
    ?? NSG rules: Subnet-level access control ?
```

**Layer 5: Managed Identity Authentication**
```
App Service (bot220214)
    ? Managed Identity token
Azure AD
    ? Validates identity
    ? Checks RBAC role
Azure OpenAI
    ? Cognitive Services OpenAI User role
    ? No API keys needed
    ? Audit trail in Azure AD
```

---

## ?? Communication Flows

### Flow 1: User Message to Bot

```
1. User in Teams
   "How can you help me?"
   ?

2. Teams Client ? Bot Framework Service
   POST https://api.botframework.com/v3/conversations/{id}/activities
   Body: { text: "How can you help me?", from: {user}, ... }
   ?

3. Bot Framework Service ? Azure Bot Service
   Looks up bot registration: bot220214
   Gets endpoint: https://bot220214-apim.azure-api.net/api/messages
   Generates JWT token
   ?

4. Bot Framework Service ? APIM
   POST https://bot220214-apim.azure-api.net/api/messages
   Authorization: Bearer {JWT}
   Body: Activity object
   ?

5. APIM ? JWT Validation
   - Validates issuer: api.botframework.com ?
   - Validates audience: 704c5df5-0b49-4a0f-accc-94e52ef13c58 ?
   - Validates expiration ?
   - Validates signature ?
   ? PASS

6. APIM ? Rate Limiting
   - Check IP: 40.xx.xx.xx (Bot Framework)
   - Count: 45/100 in last minute ?
   ? PASS

7. APIM ? App Service
   POST https://bot220214.azurewebsites.net/api/messages
   (via VNet internal routing or public IP)
   ?

8. App Service ? Access Restrictions Check
   - Source IP: 135.116.200.37 (APIM)
   - Rule: Allow-APIM-PublicIP (Priority 200) ?
   ? ALLOW

9. App Service ? Bot Code Execution
   - Receives Activity
   - Processes message
   ?

10. App Service ? Azure OpenAI
    POST https://aif-travelagent-bot.openai.azure.com/openai/deployments/gpt-4.1/chat/completions
    Authorization: Bearer {Managed Identity Token}
    (via Private Endpoint: 10.0.3.4)
    ?

11. Azure OpenAI ? Validates Managed Identity
    - Principal ID: 3edd4268-ffb1-4e61-b62c-fdb93a8f17d6 ?
    - RBAC Role: Cognitive Services OpenAI User ?
    ? AUTHORIZED

12. Azure OpenAI ? Generates Response
    "I can help you with travel planning..."
    ?

13. App Service ? Azure OpenAI
    Response with generated text
    ?

14. App Service ? Formats Bot Response
    Creates Activity with text and/or cards
    ?

15. APIM ? App Service
    HTTP 200 OK
    Body: Response activity
    ?

16. Bot Framework ? APIM
    HTTP 200 OK (with security headers)
    ?

17. Teams ? Bot Framework
    Displays message to user
    "I can help you with travel planning..."
```

**Total time:** 2-4 seconds (typical)

### Flow 2: OAuth Authentication (Optional)

```
1. Bot needs to access Microsoft Graph
   User: "Show my files"
   ?

2. Bot checks for Graph token
   var token = turnState.GetValue<TokenResponse>("token.graph");
   if (token == null) ? Trigger OAuth
   ?

3. Bot ? OAuth Card
   Returns OAuthCard to user
   "Sign in to Microsoft"
   ?

4. User clicks OAuth card
   Opens login window/popup
   ?

5. Azure AD OAuth Flow
   https://login.microsoftonline.com/{tenant}/oauth2/v2.0/authorize
   client_id: {graphConnectionClientId}
   redirect_uri: https://token.botframework.com/.auth/web/redirect
   scope: User.Read Files.Read Calendars.Read
   ?

6. User consents (delegated permissions)
   "This app wants to:
    • Read your profile
    • Read your files
    • Read your calendar"
   [Accept]
   ?

7. Azure AD ? Bot Framework Token Service
   Authorization code ? Access token
   ?

8. Bot Framework ? Bot
   Token exchange complete
   turnState.SetValue("token.graph", tokenResponse)
   ?

9. Bot ? Microsoft Graph API
   GET https://graph.microsoft.com/v1.0/me/drive/root/children
   Authorization: Bearer {accessToken}
   ?

10. Graph API ? Returns user's files
    Bot formats and displays to user
```

---

## ?? Network Traffic Patterns

### Inbound Traffic (Internet ? VNet)

```
Internet (Bot Framework: 40.xx.xx.xx)
    ? HTTPS (443)
APIM Public IP (135.116.200.37)
    ? NSG: AllowHTTPSInbound (Priority 100) ?
APIM Subnet (10.0.2.0/24)
    ? Internal routing
App Service Subnet (10.0.1.0/24)
    ? NSG: AllowAPIMSubnet (Priority 100) ?
App Service (bot220214)
    ? Access Restrictions ?
Bot Application Code
```

### Outbound Traffic (VNet ? Azure OpenAI)

```
App Service (bot220214)
    ? VNet Integration
App Service Subnet (10.0.1.0/24)
    ? VNet routing (10.0.0.0/16)
Private Endpoints Subnet (10.0.3.0/24)
    ? Private Endpoint: 10.0.3.4
Azure OpenAI (aif-travelagent-bot)
    ? Private link service
Azure OpenAI Backend (Microsoft managed)
```

### DNS Resolution Flow

```
App Service: Resolve "aif-travelagent-bot.openai.azure.com"
    ?
Azure DNS (168.63.129.16)
    ? CNAME lookup
"aif-travelagent-bot.privatelink.openai.azure.com"
    ? Private DNS Zone lookup
Private DNS Zone: privatelink.openai.azure.com
    ? A record
10.0.3.4 (Private IP in VNet)
```

---

## ?? Configuration Details

### Environment Variables (App Service)

| Variable Name | Value | Purpose |
|---------------|-------|---------|
| `Connections__BotServiceConnection__Settings__ClientId` | `704c5df5-0b49-4a0f-accc-94e52ef13c58` | Bot identity for JWT validation |
| `Connections__BotServiceConnection__Settings__TenantId` | `{tenantId}` | Azure AD tenant |
| `TokenValidation__Audiences__0` | `704c5df5-0b49-4a0f-accc-94e52ef13c58` | JWT audience validation |
| `Azure__OpenAIEndpoint` | `https://aif-travelagent-bot.openai.azure.com/` | Azure OpenAI endpoint |
| `Azure__OpenAIDeploymentName` | `gpt-4.1` | Model deployment name |
| `Azure__UseManagedIdentity` | `true` | Use Managed Identity for auth |
| `Azure__ManagedIdentityClientId` | `704c5df5-0b49-4a0f-accc-94e52ef13c58` | Managed Identity client ID |
| `AZURE_CLIENT_ID` | `704c5df5-0b49-4a0f-accc-94e52ef13c58` | Azure SDK identity |
| `WEBSITE_VNET_ROUTE_ALL` | `1` | Route all traffic through VNet |
| `WEBSITE_DNS_SERVER` | `168.63.129.16` | Azure DNS server |

### Teams App Manifest

**File:** `manifest.json`

```json
{
  "manifestVersion": "1.22",
  "version": "1.2.0",
  "id": "805c21c0-716b-4935-b2a9-c0cd15aab5a9",
  "bots": [
    {
      "botId": "704c5df5-0b49-4a0f-accc-94e52ef13c58",
      "scopes": ["copilot", "personal"],
      "supportsFiles": false,
      "isNotificationOnly": false
    }
  ],
  "permissions": [
    "identity",
    "messageTeamMembers"
  ],
  "validDomains": [
    "token.botframework.com",
    "*.botframework.com",
    "login.microsoftonline.com",
    "bot220214-apim.azure-api.net",
    "*.azure-api.net"
  ],
  "copilotAgents": {
    "customEngineAgents": [
      {
        "id": "704c5df5-0b49-4a0f-accc-94e52ef13c58",
        "type": "bot"
      }
    ]
  }
}
```

**Key Properties:**
- `botId`: Must match Managed Identity Client ID
- `permissions`: `identity` enables OAuth flows
- `validDomains`: Required for OAuth redirects and content embedding
- `copilotAgents`: Enables Microsoft 365 Copilot integration

---

## ?? Resource Summary

| Resource Type | Name | SKU/Tier | Location | Purpose |
|---------------|------|----------|----------|---------|
| **Bot Service** | bot220214 | F0 (Free) | Global | Bot registration & Teams channel |
| **APIM** | bot220214-apim | Developer | Sweden Central | Reverse proxy & security gateway |
| **Public IP** | bot220214-apim-pip | Standard | Sweden Central | APIM static public IP |
| **VNet** | bot220214-vnet | - | Sweden Central | Network isolation |
| **NSG (APIM)** | bot220214-apim-nsg | - | Sweden Central | APIM subnet security |
| **NSG (App Service)** | bot220214-appservice-nsg | - | Sweden Central | App Service subnet security |
| **App Service Plan** | bot220214 | B1 (Basic) | Sweden Central | Compute for App Service |
| **App Service** | bot220214 | - | Sweden Central | Bot application hosting |
| **Managed Identity** | bot220214 | User-Assigned | Sweden Central | Credential-free auth |
| **Azure OpenAI** | aif-travelagent-bot | S0 (Standard) | Sweden Central | GPT-4 model hosting |
| **Private Endpoint** | bot220214-openai-pe | - | Sweden Central | Azure OpenAI private access |
| **Private DNS Zone** | privatelink.openai.azure.com | - | Global | Private DNS resolution |

**Total Monthly Cost Estimate (Approximate):**
- Bot Service: Free (F0 tier)
- APIM: ~$50 (Developer tier)
- Public IP: ~$4
- App Service Plan: ~$13 (B1 tier)
- Azure OpenAI: ~$Variable (pay per token)
- Private Endpoint: ~$7
- VNet: Free
- NSGs: Free
- Managed Identity: Free
- **Total: ~$74/month** (plus OpenAI usage)

---

## ?? Deployment

### Prerequisites

1. ? Azure subscription
2. ? Azure CLI installed
3. ? Visual Studio with Teams Toolkit extension
4. ? .NET 9 SDK installed
5. ? Azure OpenAI resource provisioned with GPT-4 model

### Deployment Steps

**1. Provision Infrastructure:**

```powershell
cd M365Agent

# Via Teams Toolkit (Recommended)
# Visual Studio: Ctrl+Shift+P
# ? Teams Toolkit: Provision
# ? Select: dev environment

# Or via Azure CLI
az deployment group create `
  --resource-group rg-travelagent-bot-5555 `
  --template-file infra/azure.bicep `
  --parameters @.azure/dev.parameters.json
```

**2. Deploy Application Code:**

```powershell
# Via Teams Toolkit
# Visual Studio: Ctrl+Shift+P
# ? Teams Toolkit: Deploy
# ? Select: dev environment

# Or via CLI
dotnet publish TravelAgent -c Release -o ./publish
Compress-Archive -Path ./publish/* -DestinationPath ./app.zip
az webapp deployment source config-zip `
  --resource-group rg-travelagent-bot-5555 `
  --name bot220214 `
  --src ./app.zip
```

**3. Publish Teams App:**

```powershell
# Via Teams Toolkit
# Visual Studio: Ctrl+Shift+P
# ? Teams Toolkit: Publish
# ? Select: dev environment
# ? Publish to Teams
```

**4. Install in Teams:**

1. Open Microsoft Teams
2. Go to **Apps** ? **Built for your org**
3. Find **Travel Agent 1.2-APIM VNet**
4. Click **Add**

---

## ?? Testing & Verification

### Test 1: Basic Connectivity

```powershell
# Test APIM endpoint (should return 401 - requires JWT)
Invoke-WebRequest -Uri "https://bot220214-apim.azure-api.net/api/messages" -Method POST

# Expected: 401 Unauthorized (correct - needs Bot Framework JWT)
```

### Test 2: Direct App Service Access

```powershell
# Try to access App Service directly (should fail)
Invoke-WebRequest -Uri "https://bot220214.azurewebsites.net/api/messages" -Method POST

# Expected: 403 Forbidden (blocked by access restrictions) ?
```

### Test 3: Bot Functionality

```
Teams ? Bot Chat
You: "How can you help me?"
Bot: "I can help you with travel planning..."

Expected: Response within 3-5 seconds ?
```

### Test 4: OAuth Flow (if implemented)

```
You: "Show my files"
Bot: [OAuth Card: "Sign in to Microsoft"]
Click card ? Sign in ? Consent
Expected: No "Need admin approval" message ?
Bot: "Here are your files..."
```

### Verification Commands

```powershell
# Check Bot Service configuration
az bot show --name bot220214 --resource-group rg-travelagent-bot-5555

# Check APIM metrics
az monitor metrics list `
  --resource /subscriptions/.../bot220214-apim `
  --metric Requests `
  --start-time (Get-Date).AddHours(-1)

# Check App Service logs
az webapp log tail --name bot220214 --resource-group rg-travelagent-bot-5555

# Verify Managed Identity role
$identityId = az identity show --name bot220214 --resource-group rg-travelagent-bot-5555 --query principalId -o tsv
az role assignment list --assignee $identityId

# Check access restrictions
az webapp config access-restriction show --name bot220214 --resource-group rg-travelagent-bot-5555
```

---

## ?? Troubleshooting

### Issue: Bot not responding in Teams

**Diagnosis:**
```powershell
# 1. Check if APIM is receiving requests
az monitor metrics list --resource /subscriptions/.../bot220214-apim --metric Requests

# 2. Check APIM diagnostics
# Azure Portal ? APIM ? Application Insights ? Failures

# 3. Check App Service logs
az webapp log tail --name bot220214 --resource-group rg-travelagent-bot-5555
```

**Common causes:**
- ? JWT validation failure (check APIM policy audiences)
- ? Access restrictions blocking APIM (add APIM IP)
- ? Managed Identity missing role (assign OpenAI User role)
- ? Azure OpenAI private endpoint DNS issue

### Issue: 401 Unauthorized from APIM

**Cause:** JWT audience mismatch

**Fix:**
```bicep
// In apim.bicep, ensure audiences include:
<audiences>
  <audience>704c5df5-0b49-4a0f-accc-94e52ef13c58</audience>
  <audience>https://bot220214-apim.azure-api.net</audience>
  <audience>https://api.botframework.com</audience>
</audiences>
```

### Issue: 403 Forbidden from App Service

**Cause:** Access restrictions blocking APIM

**Fix:**
```powershell
# Add APIM IP to allow list
az webapp config access-restriction add `
  --name bot220214 `
  --resource-group rg-travelagent-bot-5555 `
  --rule-name "Allow-APIM" `
  --action Allow `
  --ip-address "135.116.200.37/32" `
  --priority 200
```

### Issue: OAuth shows "Need admin approval"

**Cause:** Application permissions (*.All scopes) instead of delegated

**Fix:**
```bicep
// In botRegistration/azurebot.bicep
scopes: 'User.Read Files.Read Calendars.Read'  // Delegated permissions
// NOT: 'Files.Read.All Sites.Read.All'  // Application permissions
```

---

## ?? Best Practices

### Security

1. ? **Use Managed Identity** - Never store credentials in code
2. ? **Principle of Least Privilege** - Grant minimum required permissions
3. ? **Defense in Depth** - Multiple security layers (JWT, access restrictions, NSG, VNet)
4. ? **Private Endpoints** - Keep sensitive resources off public internet
5. ? **TLS 1.2+** - Disable older protocols
6. ? **Rate Limiting** - Protect against abuse

### Networking

1. ? **VNet Integration** - Isolate App Service in private network
2. ? **APIM External Mode** - Public gateway, private backend
3. ? **NSG Rules** - Network-level access control
4. ? **Access Restrictions** - Application-level IP allowlisting
5. ? **Private DNS** - Use Azure Private DNS zones

### Operations

1. ? **Infrastructure as Code** - All resources in Bicep
2. ? **Monitoring** - Application Insights for APIM and App Service
3. ? **Logging** - Enable diagnostic logging
4. ? **Alerting** - Set up alerts for failures
5. ? **Documentation** - Keep architecture docs updated

### Development

1. ? **Environment Separation** - dev, staging, prod environments
2. ? **CI/CD** - Automated deployments
3. ? **Version Control** - All code and infrastructure in Git
4. ? **Testing** - Unit tests, integration tests, E2E tests
5. ? **Code Review** - Peer review before merging

---

## ?? References

### Microsoft Documentation

- [Azure Bot Service](https://learn.microsoft.com/en-us/azure/bot-service/)
- [Azure API Management](https://learn.microsoft.com/en-us/azure/api-management/)
- [Azure Virtual Network](https://learn.microsoft.com/en-us/azure/virtual-network/)
- [Azure App Service](https://learn.microsoft.com/en-us/azure/app-service/)
- [Azure OpenAI Service](https://learn.microsoft.com/en-us/azure/ai-services/openai/)
- [Managed Identities](https://learn.microsoft.com/en-us/entra/identity/managed-identities-azure-resources/)
- [Private Endpoints](https://learn.microsoft.com/en-us/azure/private-link/private-endpoint-overview)

### Related Documentation

- `SESSION_COMPLETE_SUMMARY.md` - Complete session overview
- `FIX_APIM_JWT_AUDIENCE_VALIDATION.md` - JWT validation fix details
- `FIX_APP_SERVICE_403_ACCESS_RESTRICTIONS.md` - Access restrictions fix
- `BICEP_ROLE_ASSIGNMENT_ADDED.md` - Managed Identity role assignment
- `ENABLE_SSO_WITHOUT_ADMIN_CONSENT.md` - OAuth configuration
- `BOT_SERVICE_NOT_IN_VNET.md` - Bot Service architecture explanation

---

## ?? Revision History

| Version | Date | Author | Changes |
|---------|------|--------|---------|
| 1.0 | 2024-01-11 | System | Initial reference architecture |

---

## ?? Summary

This reference architecture provides:

? **Enterprise Security**
- Defense-in-depth with 5 security layers
- Managed Identity (no credentials)
- Private networking with VNet isolation
- JWT validation and rate limiting

? **Bot Framework Compatibility**
- Public APIM gateway for Bot Framework Service
- Correct Bot Service configuration (no Private Endpoint)
- Proper JWT audience configuration

? **Scalability**
- APIM for load balancing and caching
- App Service can scale independently
- Azure OpenAI handles inference at scale

? **Maintainability**
- Infrastructure as Code (Bicep)
- Comprehensive documentation
- Clear separation of concerns

? **Cost Optimization**
- Basic/Developer tiers for non-production
- Pay-per-use for Azure OpenAI
- Free Bot Service tier

**This architecture is production-ready and follows Azure best practices.** ??
