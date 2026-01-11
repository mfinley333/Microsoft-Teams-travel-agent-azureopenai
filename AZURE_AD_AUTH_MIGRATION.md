# Azure OpenAI Authentication Migration

## Overview
This project has been updated to use **Azure AD (Entra ID) authentication** instead of API keys for Azure OpenAI, as API key authentication is now disabled in Azure Foundry.

## Configuration Changes

### 1. Environment Variables (`.env.dev.user`)
The following variables have been updated:

**Removed:**
- `SECRET_AZURE_OPENAI_API_KEY` (no longer supported)

**Added:**
- `USE_MANAGED_IDENTITY` - Set to `true` for Azure deployments (uses Managed Identity), `false` for local development (uses Service Principal)

### 2. Infrastructure Changes
The following files have been updated to support Azure AD authentication:
- `M365Agent/infra/azure.bicep` - Removed API key parameter, configured for Managed Identity
- `M365Agent/infra/azure.parameters.json` - Updated to pass only required parameters
- The Bicep template now creates a User-Assigned Managed Identity and configures the App Service to use it

### 3. Authentication Methods

#### Method 1: Managed Identity (Azure Deployment - Default)
When deployed to Azure App Service:
1. Set `USE_MANAGED_IDENTITY=true` in `.env.dev.user` (already configured)
2. Run provision - the deployment will automatically:
   - Create a User-Assigned Managed Identity
   - Configure the App Service with the Managed Identity
   - Set up environment variables for authentication
3. **Important:** After deployment, grant the Managed Identity access (see Step 3 below)

#### Method 2: Service Principal (Local Development)
For local development:
1. Set `USE_MANAGED_IDENTITY=false` in `.env.dev.user`
2. Create an Azure AD App Registration
3. Create a client secret
4. Grant the app the **"Cognitive Services OpenAI User"** role on your Azure OpenAI resource
5. Update `TravelAgent/appsettings.Development.json` with your credentials:
   ```json
   "Azure": {
     "OpenAIEndpoint": "https://your-resource.openai.azure.com/",
     "OpenAIDeploymentName": "your-deployment-name",
     "UseManagedIdentity": false,
     "ClientId": "your-app-client-id",
     "ClientSecret": "your-app-client-secret",
     "TenantId": "your-tenant-id"
   }
   ```

## Setup Instructions

### Step 1: Update Environment Variables (Already Configured)
Your `.env.dev.user` is already configured for Managed Identity:
```
USE_MANAGED_IDENTITY=true
AZURE_OPENAI_ENDPOINT=https://aif-travelagent-bot.openai.azure.com/
AZURE_OPENAI_DEPLOYMENT_NAME=gpt-4.1
```

### Step 2: Provision/Deploy to Azure
Run the provision command:
```
Teams Toolkit: Provision in the Cloud
```

The Bicep template will automatically:
- Deploy your App Service
- Create a User-Assigned Managed Identity named `bot<RESOURCE_SUFFIX>`
- Configure the App Service to use this Managed Identity
- Set environment variables: `Azure__UseManagedIdentity=true`

### Step 3: Grant Azure OpenAI Access (Critical Manual Step)
**After successful deployment**, you must grant the Managed Identity access to your Azure OpenAI resource:

1. Go to Azure Portal
2. Navigate to your Azure OpenAI resource: **aif-travelagent-bot**
3. Click **Access Control (IAM)** in the left menu
4. Click **+ Add** ? **Add role assignment**
5. In the "Role" tab:
   - Search for and select **Cognitive Services OpenAI User**
   - Click **Next**
6. In the "Members" tab:
   - Select **Managed Identity**
   - Click **+ Select members**
   - Filter by "User-assigned managed identity"
   - Find and select your identity: **bot220214** (or your RESOURCE_SUFFIX)
   - Click **Select**
   - Click **Next**
7. Click **Review + assign**

**Wait 2-5 minutes** for the role assignment to propagate before testing.

## Code Changes Summary

### Files Modified:
- `TravelAgent/Program.cs` - Uses `DefaultAzureCredential` or `ClientSecretCredential` based on `UseManagedIdentity` setting
- `TravelAgent/Config.cs` - Removed `OpenAIApiKey`, added Azure AD properties
- `TravelAgent/appsettings.Development.json` - Updated configuration structure
- `M365Agent/env/.env.dev.user` - Simplified to only required variables
- `M365Agent/infra/azure.bicep` - Configured for Managed Identity
- `M365Agent/infra/azure.parameters.json` - Removed optional parameters

### Key Changes:
```csharp
// Old (API Key)
new AzureOpenAIClient(
    new Uri(endpoint),
    new AzureKeyCredential(apiKey))

// New (Managed Identity on Azure)
new AzureOpenAIClient(
    new Uri(endpoint),
    new DefaultAzureCredential())
```

## Troubleshooting

### Error: "Missing environment variables 'SECRET_AZURE_CLIENT_ID'..."
- **Fixed!** These variables are no longer required in the infrastructure
- Only `USE_MANAGED_IDENTITY` is needed in `.env.dev.user`

### Error: "Unauthorized" or "403 Forbidden" when calling Azure OpenAI
- The Managed Identity doesn't have access yet
- Follow **Step 3** above to grant the "Cognitive Services OpenAI User" role
- Wait 2-5 minutes for role assignment to propagate
- Restart your App Service after granting access

### Error: "DefaultAzureCredential authentication failed"
- Ensure the Managed Identity was created during deployment
- Check Azure Portal ? App Service ? Identity ? User assigned
- Verify the identity exists and is assigned to the App Service
- Verify `Azure__UseManagedIdentity` is set to `true` in App Service configuration

### Local Development: "ClientSecretCredential authentication failed"
- Ensure `USE_MANAGED_IDENTITY=false` in `.env.dev.user`
- Update `appsettings.Development.json` with valid Client ID, Secret, and Tenant ID
- Verify the Service Principal has "Cognitive Services OpenAI User" role

### How to verify Managed Identity was created
1. Go to Azure Portal ? Resource Groups ? Your resource group
2. Look for a resource named `bot<RESOURCE_SUFFIX>` of type "Managed Identity"
3. Click on it and note the Client ID
4. Go to your App Service ? Identity ? User assigned
5. Verify this Managed Identity is listed

## Testing After Deployment

1. Open Microsoft 365 Agents Playground (formerly Test Tool)
2. Send a message to your agent
3. If you get a 403 error, check:
   - The Managed Identity has the role assignment (Step 3)
   - Wait a few more minutes for propagation
   - Restart the App Service

## References
- [Azure OpenAI with Managed Identity](https://learn.microsoft.com/en-us/azure/ai-services/openai/how-to/managed-identity)
- [Azure Identity SDK](https://learn.microsoft.com/en-us/dotnet/api/overview/azure/identity-readme)
- [Managed Identity Overview](https://learn.microsoft.com/en-us/entra/identity/managed-identities-azure-resources/overview)
- [Bicep User-Assigned Managed Identity](https://learn.microsoft.com/en-us/azure/templates/microsoft.managedidentity/userassignedidentities)
