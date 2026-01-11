# Quick Start: Provisioning with Managed Identity

## ? You're Ready to Provision!

Your configuration is already set up correctly. Here's what to do:

### 1. Provision to Azure
Run: **Teams Toolkit: Provision in the Cloud**

The deployment will:
- ? Create your App Service
- ? Create a Managed Identity named `bot220214`
- ? Configure the app to use Managed Identity

### 2. Grant Azure OpenAI Access (Manual Step - Required!)

After provision succeeds:

1. **Open Azure Portal** ? Search for "aif-travelagent-bot" (your OpenAI resource)
2. Click **Access Control (IAM)** on the left
3. Click **+ Add** ? **Add role assignment**
4. Select role: **Cognitive Services OpenAI User** ? Next
5. Click **Managed Identity** ? **+ Select members**
6. Find and select: **bot220214** ? Select ? Next
7. Click **Review + assign**

?? **Wait 2-5 minutes** for the role to propagate

### 3. Deploy Your Code
Run: **Teams Toolkit: Deploy to the Cloud**

### 4. Test Your Agent
Open Microsoft 365 Agents Playground and send a message!

---

## If You Get a 403 Error

This means the Managed Identity doesn't have access yet:
- Did you complete Step 2 above?
- Wait a few more minutes
- Restart your App Service in Azure Portal

---

## Current Configuration

? `.env.dev.user`:
- `USE_MANAGED_IDENTITY=true` ?
- `AZURE_OPENAI_ENDPOINT=https://aif-travelagent-bot.openai.azure.com/` ?
- `AZURE_OPENAI_DEPLOYMENT_NAME=gpt-4.1` ?

? Infrastructure:
- `azure.bicep` - Configured for Managed Identity ?
- `azure.parameters.json` - Only requires variables that exist ?

? Code:
- `Program.cs` - Uses `DefaultAzureCredential` when `UseManagedIdentity=true` ?

---

## What Changed?

**Before:** Required API key (`SECRET_AZURE_OPENAI_API_KEY`)
**Now:** Uses Managed Identity (no secrets in code!)

**Benefits:**
- ?? More secure (no API keys to manage)
- ?? Simpler deployment (fewer secrets)
- ? Azure-native authentication

---

See `AZURE_AD_AUTH_MIGRATION.md` for detailed documentation and troubleshooting.
