// Role assignment module for cross-resource-group deployments
param openAIAccountName string
param managedIdentityPrincipalId string
param roleDefinitionId string

// Reference existing Azure OpenAI resource (in the current scope - the module is deployed to the target resource group)
resource openAIAccount 'Microsoft.CognitiveServices/accounts@2023-05-01' existing = {
  name: openAIAccountName
}

// Role assignment: Grant Managed Identity access to Azure OpenAI
// Use extension resource syntax - deployed at the OpenAI account scope
resource openAIRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(openAIAccount.id, managedIdentityPrincipalId, roleDefinitionId)
  scope: openAIAccount
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', roleDefinitionId)
    principalId: managedIdentityPrincipalId
    principalType: 'ServicePrincipal'
  }
}

output roleAssignmentId string = openAIRoleAssignment.id
