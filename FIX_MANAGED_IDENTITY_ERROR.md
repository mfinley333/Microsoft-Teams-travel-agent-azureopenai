# Fix: Managed Identity Authentication Error

## What Changed

I've updated the code to:
1. ? **Add detailed logging** - See exactly what's happening during authentication
2. ? **Explicitly specify Managed Identity Client ID** - No ambiguity about which identity to use
3. ? **Add `AZURE_CLIENT_ID` environment variable** - Standard Azure SDK convention
4. ? **Better error handling** - Clear error messages if something goes wrong

## Files Modified

- `TravelAgent/Program.cs` - Added logging and explicit Managed Identity Client ID support
- `TravelAgent/Config.cs` - Added `ManagedIdentityClientId` property
- `M365Agent/infra/azure.bicep` - Added environment variables for Managed Identity Client ID

## Next Steps

### 1. Redeploy the Application

Run these commands in order:

```
1. Teams Toolkit: Provision in the Cloud
   (This updates the infrastructure with new environment variables)

2. Teams Toolkit: Deploy to the Cloud
   (This deploys the updated code with better logging)
```

### 2. Check the Logs (Critical for Debugging)

After deploying, immediately check the logs to see what's happening:

**Option A: Azure Portal Log Stream (Real-time)**
1. Go to Azure Portal ? Your App Service (`bot220214`)
2. Click **Log stream** in the left menu
3. Send a message to your bot in Teams
4. You should now see detailed logs like:
   ```
   Configuring Azure OpenAI authentication...
   UseManagedIdentity: True
   OpenAI Endpoint: https://aif-travelagent-bot.openai.azure.com/
   Deployment Name: gpt-4.1
   Using User-Assigned Managed Identity with Client ID: xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx
   Creating Azure OpenAI client...
   Azure OpenAI client created successfully
   ```

**Option B: Application Insights (If enabled)**
1. Go to Azure Portal ? Your App Service
2. Click **Application Insights** ? **Logs**
3. Run this query:
```kusto
traces
| where timestamp > ago(30m)
| where message contains "Azure" or message contains "Managed"
| order by timestamp desc
```

### 3. Verify Environment Variables

In Azure Portal ? App Service ? **Environment variables**, verify these exist:

| Name | Expected Value |
|------|----------------|
| `Azure__UseManagedIdentity` | `true` |
| `Azure__ManagedIdentityClientId` | `<guid>` (auto-set by Bicep) |
| `AZURE_CLIENT_ID` | `<same guid>` (standard Azure SDK variable) |
| `Azure__OpenAIEndpoint` | `https://aif-travelagent-bot.openai.azure.com/` |
| `Azure__OpenAIDeploymentName` | `gpt-4.1` |

### 4. Verify Managed Identity Configuration

1. In App Service ? **Identity** ? **User assigned**
2. Verify `bot220214` is listed
3. Click on it and note the **Client ID** - it should match the values above

### 5. Verify Azure OpenAI Role Assignment

1. Go to your Azure OpenAI resource: `aif-travelagent-bot`
2. Click **Access Control (IAM)**
3. Click **Role assignments**
4. Search for `bot220214` (your managed identity name)
5. Verify it has role: **Cognitive Services OpenAI User**

If not found:
- Click **+ Add** ? **Add role assignment**
- Role: **Cognitive Services OpenAI User**
- Members: Select **Managed Identity** ? `bot220214`
- Click **Review + assign**

### 6. Test Again

1. **Restart the App Service** (important after environment variable changes)
2. Wait 1-2 minutes
3. Send a message to your bot in Teams
4. Check the logs immediately

## What the Logs Tell You

### ? Success Pattern
```
Configuring Azure OpenAI authentication...
UseManagedIdentity: True
Using User-Assigned Managed Identity with Client ID: 12345678-1234-1234-1234-123456789abc
Creating Azure OpenAI client...
Azure OpenAI client created successfully
```

### ? Common Error Patterns

**Error 1: "Unable to load the proper Managed Identity"**
- **Cause:** Identity not assigned to App Service
- **Fix:** Verify Step 4 above

**Error 2: "UseManagedIdentity: False"**
- **Cause:** Environment variable not set or wrong value
- **Fix:** Check `Azure__UseManagedIdentity` in App Service config, should be string `"true"`

**Error 3: "Authorization failed" or "403 Forbidden"**
- **Cause:** Managed Identity exists but doesn't have permission
- **Fix:** Verify Step 5 above (role assignment)

**Error 4: "ManagedIdentityClientId is null or empty"**
- **Cause:** Bicep didn't set the variable
- **Fix:** Re-run Provision

## Alternative: Manual Configuration (If Provision Fails)

If the automated provision doesn't work, manually add these environment variables in Azure Portal:

1. Go to App Service ? **Environment variables**
2. Click **+ Add**
3. Add each variable:

```
Name: Azure__ManagedIdentityClientId
Value: <Copy from Identity ? User assigned ? bot220214 ? Client ID>

Name: AZURE_CLIENT_ID
Value: <Same as above>
```

4. Click **Save** ? **Continue**
5. **Restart** the App Service

## Still Not Working?

If you still see errors after following all steps above, share:
1. The **exact error message** from the logs
2. Screenshot of App Service ? **Identity** ? **User assigned** tab
3. Screenshot of App Service ? **Environment variables** (filter for "Azure")
4. Screenshot of Azure OpenAI ? **Access Control (IAM)** ? **Role assignments**

We'll debug further from there!
