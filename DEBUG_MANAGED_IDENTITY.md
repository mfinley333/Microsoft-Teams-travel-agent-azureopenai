# Debug Managed Identity Issues

## Step 1: Check Azure App Service Logs

### Option A: View Live Logs in Azure Portal
1. Go to **Azure Portal** ? Your App Service (`bot220214`)
2. Click **Log stream** in the left menu
3. Send a message to your bot in Teams
4. Watch for errors related to Azure.Identity or ManagedIdentity

### Option B: Download Application Logs
1. In your App Service, click **Diagnose and solve problems**
2. Search for "Application Logs"
3. Or go to **Monitoring** ? **Logs** and run this query:
```kusto
AppServiceConsoleLogs
| where TimeGenerated > ago(1h)
| order by TimeGenerated desc
| project TimeGenerated, ResultDescription
```

## Step 2: Verify Environment Variables in Azure

1. Go to **Azure Portal** ? Your App Service
2. Click **Environment variables** (or **Configuration** ? **Application settings**)
3. **Verify these exact settings exist:**

| Name | Expected Value | Current Value |
|------|---------------|---------------|
| `Azure__UseManagedIdentity` | `true` | ? |
| `Azure__OpenAIEndpoint` | `https://aif-travelagent-bot.openai.azure.com/` | ? |
| `Azure__OpenAIDeploymentName` | `gpt-4.1` | ? |
| `MANAGED_IDENTITY_CLIENT_ID` | (leave empty or Client ID of managed identity) | ? |

**Important:** The `Azure__UseManagedIdentity` setting must be the STRING `"true"`, not a boolean.

## Step 3: Check Managed Identity Assignment

1. In App Service, go to **Identity** ? **User assigned**
2. Verify `bot220214` is listed
3. Click on the managed identity name
4. Note the **Client ID** (looks like: `12345678-1234-1234-1234-123456789abc`)

## Step 4: Test Managed Identity Endpoint (Advanced)

SSH into your App Service and test if the Managed Identity endpoint responds:

1. In App Service, go to **Development Tools** ? **SSH** ? **Go**
2. Run these commands:
```bash
# Check if Managed Identity endpoint is available
curl -H "Metadata:true" "$IDENTITY_ENDPOINT?resource=https://cognitiveservices.azure.com&api-version=2019-08-01"
```

If this returns a token, Managed Identity is working. If it fails, the identity isn't properly configured.

## Step 5: Enable Detailed Logging

Add these environment variables temporarily for debugging:

| Name | Value |
|------|-------|
| `AZURE_LOG_LEVEL` | `verbose` |
| `Logging__LogLevel__Azure` | `Debug` |
| `Logging__LogLevel__Azure.Identity` | `Debug` |

Then restart the app and check logs again.

## Step 6: Check System vs User Assigned Identity

The code uses `DefaultAzureCredential` which tries multiple authentication methods in order:
1. Environment variables (not set)
2. Managed Identity (System or User assigned)
3. Azure CLI (not available in App Service)
4. Others...

**Issue:** If you have BOTH System and User assigned identities, it might use the wrong one.

**Solution:** Explicitly specify which identity to use (see code fix below).

## Common Issues and Solutions

### Issue 1: User-Assigned Identity Not Recognized
**Symptom:** Error says "Unable to load the proper Managed Identity"
**Cause:** `DefaultAzureCredential` can't find the User-Assigned Identity
**Solution:** Explicitly pass the Client ID to `DefaultAzureCredential`

### Issue 2: Configuration Not Being Read
**Symptom:** `Azure__UseManagedIdentity` is `true` but code uses wrong value
**Cause:** Configuration binding issue or wrong environment
**Solution:** Check if `RUNNING_ON_AZURE` environment variable is set to `1`

### Issue 3: Wrong Identity Being Used
**Symptom:** Token acquired but still fails to call OpenAI
**Cause:** Using System-Assigned Identity without proper role assignment
**Solution:** Use User-Assigned Identity with explicit Client ID

---

## Next Steps After Debugging

Based on what you find in the logs, we may need to:
1. Update the code to explicitly specify the Managed Identity Client ID
2. Switch from User-Assigned to System-Assigned Identity
3. Fix configuration binding issues
4. Add retry logic with better error messages

Run through Steps 1-3 above and share what you find!
