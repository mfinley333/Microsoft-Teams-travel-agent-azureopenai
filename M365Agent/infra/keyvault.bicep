// Azure Key Vault for storing certificates and secrets
// Used for certificate-based SSO authentication and secure secret storage

@description('Base name for resources')
param resourceBaseName string

@description('Location for all resources')
param location string = resourceGroup().location

@description('Managed Identity Principal ID that needs access')
param managedIdentityPrincipalId string

@description('Managed Identity Resource ID')
param managedIdentityId string

@description('Azure AD Tenant ID')
param tenantId string = tenant().tenantId

@description('Enable soft delete for Key Vault')
param enableSoftDelete bool = true

@description('Create SSO certificate (set to false to skip if certificate already exists)')
param createCertificate bool = false

@description('Soft delete retention days')
param softDeleteRetentionInDays int = 90

@description('Deploy private endpoint for Key Vault')
param deployPrivateEndpoint bool = true

@description('Private endpoint subnet ID')
param privateEndpointSubnetId string = ''

@description('VNet ID for private DNS zone')
param vnetId string = ''

@description('AAD App Client Secret for OBO flow (optional - can be set manually)')
@secure()
param aadAppClientSecret string = ''

// Key Vault
resource keyVault 'Microsoft.KeyVault/vaults@2022-07-01' = {
  name: '${resourceBaseName}-kv'
  location: location
  properties: {
    sku: {
      family: 'A'
      name: 'standard'
    }
    tenantId: tenantId
    enableRbacAuthorization: true  // Use RBAC instead of access policies
    enableSoftDelete: enableSoftDelete
    softDeleteRetentionInDays: softDeleteRetentionInDays
    enabledForDeployment: false
    enabledForDiskEncryption: false
    enabledForTemplateDeployment: true
    publicNetworkAccess: deployPrivateEndpoint ? 'Disabled' : 'Enabled'
    networkAcls: {
      bypass: 'AzureServices'
      defaultAction: deployPrivateEndpoint ? 'Deny' : 'Allow'
      virtualNetworkRules: []
      ipRules: []
    }
  }
}

// Grant Managed Identity access to Key Vault Secrets
resource keyVaultSecretsUserRole 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(managedIdentityId, keyVault.id, 'Key Vault Secrets User')
  scope: keyVault
  properties: {
    roleDefinitionId: subscriptionResourceId(
      'Microsoft.Authorization/roleDefinitions',
      '4633458b-17de-408a-b874-0445c86b69e6'  // Key Vault Secrets User
    )
    principalId: managedIdentityPrincipalId
    principalType: 'ServicePrincipal'
  }
}

// Grant Managed Identity access to Key Vault Certificates
resource keyVaultCertificateUserRole 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(managedIdentityId, keyVault.id, 'Key Vault Certificate User')
  scope: keyVault
  properties: {
    roleDefinitionId: subscriptionResourceId(
      'Microsoft.Authorization/roleDefinitions',
      'db79e9a7-68ee-4b58-9aeb-b90e7c24fcba'  // Key Vault Certificate User
    )
    principalId: managedIdentityPrincipalId
    principalType: 'ServicePrincipal'
  }
}

// Grant Managed Identity access to Key Vault Crypto User (for signing operations)
resource keyVaultCryptoUserRole 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(managedIdentityId, keyVault.id, 'Key Vault Crypto User')
  scope: keyVault
  properties: {
    roleDefinitionId: subscriptionResourceId(
      'Microsoft.Authorization/roleDefinitions',
      '12338af0-0e69-4776-bea7-57ae8d297424'  // Key Vault Crypto User
    )
    principalId: managedIdentityPrincipalId
    principalType: 'ServicePrincipal'
  }
}

// Create certificate for SSO (self-signed)
// Note: In production, you may want to use a CA-signed certificate
// Only create if createCertificate parameter is true
resource ssoCertificate 'Microsoft.KeyVault/vaults/certificates@2022-07-01' = if (createCertificate) {
  parent: keyVault
  name: 'bot-sso-cert'
  properties: {
    certificatePolicy: {
      issuerParameters: {
        name: 'Self'  // Self-signed for development/testing
      }
      keyProperties: {
        exportable: true
        keySize: 2048
        keyType: 'RSA'
        reuseKey: false
      }
      lifetimeActions: [
        {
          action: {
            actionType: 'AutoRenew'
          }
          trigger: {
            daysBeforeExpiry: 90
          }
        }
      ]
      secretProperties: {
        contentType: 'application/x-pkcs12'
      }
      x509CertificateProperties: {
        keyUsage: [
          'cRLSign'
          'dataEncipherment'
          'digitalSignature'
          'keyEncipherment'
          'keyAgreement'
          'keyCertSign'
        ]
        subject: 'CN=bot-sso-${resourceBaseName}'
        validityInMonths: 12
        ekus: [
          '1.3.6.1.5.5.7.3.1'  // Server Authentication
          '1.3.6.1.5.5.7.3.2'  // Client Authentication
        ]
        subjectAlternativeNames: {
          dnsNames: [
            '${resourceBaseName}.azurewebsites.net'
          ]
        }
      }
    }
  }
}

// Store AAD App Client Secret for OBO flow (if provided)
// This secret is used by the bot to exchange user tokens for Graph API tokens
resource aadAppSecretStore 'Microsoft.KeyVault/vaults/secrets@2022-07-01' = if (!empty(aadAppClientSecret)) {
  parent: keyVault
  name: 'AadAppSecret'
  properties: {
    value: aadAppClientSecret
    contentType: 'text/plain'
    attributes: {
      enabled: true
    }
  }
}

// Private Endpoint for Key Vault
resource keyVaultPrivateEndpoint 'Microsoft.Network/privateEndpoints@2021-05-01' = if (deployPrivateEndpoint && !empty(privateEndpointSubnetId)) {
  name: '${resourceBaseName}-kv-pe'
  location: location
  properties: {
    subnet: {
      id: privateEndpointSubnetId
    }
    privateLinkServiceConnections: [
      {
        name: '${resourceBaseName}-kv-plsc'
        properties: {
          privateLinkServiceId: keyVault.id
          groupIds: [
            'vault'
          ]
        }
      }
    ]
  }
}

// Private DNS Zone for Key Vault
resource keyVaultPrivateDnsZone 'Microsoft.Network/privateDnsZones@2020-06-01' = if (deployPrivateEndpoint && !empty(vnetId)) {
  name: 'privatelink.vaultcore.azure.net'
  location: 'global'
}

// Link Private DNS Zone to VNet
resource keyVaultPrivateDnsZoneLink 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2020-06-01' = if (deployPrivateEndpoint && !empty(vnetId)) {
  parent: keyVaultPrivateDnsZone
  name: '${resourceBaseName}-kv-dns-link'
  location: 'global'
  properties: {
    registrationEnabled: false
    virtualNetwork: {
      id: vnetId
    }
  }
}

// DNS Zone Group for Private Endpoint
resource keyVaultPrivateDnsZoneGroup 'Microsoft.Network/privateEndpoints/privateDnsZoneGroups@2021-05-01' = if (deployPrivateEndpoint && !empty(privateEndpointSubnetId)) {
  parent: keyVaultPrivateEndpoint
  name: 'default'
  properties: {
    privateDnsZoneConfigs: [
      {
        name: 'privatelink-vaultcore-azure-net'
        properties: {
          privateDnsZoneId: keyVaultPrivateDnsZone.id
        }
      }
    ]
  }
}

// Outputs
output keyVaultId string = keyVault.id
output keyVaultName string = keyVault.name
output keyVaultUri string = keyVault.properties.vaultUri
output certificateName string = createCertificate ? ssoCertificate.name : 'bot-sso-cert'
output certificateSecretId string = '${keyVault.properties.vaultUri}secrets/${createCertificate ? ssoCertificate.name : 'bot-sso-cert'}'
output certificateId string = createCertificate ? ssoCertificate.properties.secretId : '${keyVault.properties.vaultUri}secrets/bot-sso-cert'
output privateEndpointId string = deployPrivateEndpoint ? keyVaultPrivateEndpoint.id : ''
output privateDnsZoneId string = deployPrivateEndpoint ? keyVaultPrivateDnsZone.id : ''
output aadAppSecretUri string = !empty(aadAppClientSecret) ? aadAppSecretStore.properties.secretUri : '${keyVault.properties.vaultUri}secrets/AadAppSecret'
output aadAppSecretName string = 'AadAppSecret'
