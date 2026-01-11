namespace TravelAgent
{
    public class ConfigOptions
    {
        public AzureConfigOptions Azure { get; set; }
    }

    /// <summary>
    /// Options for Azure OpenAI and Azure Content Safety
    /// </summary>
    public class AzureConfigOptions
    {
        public string OpenAIEndpoint { get; set; }
        public string OpenAIDeploymentName { get; set; }
        
        // Azure AD Authentication
        public bool UseManagedIdentity { get; set; }
        
        // Optional: Specify the Client ID of a User-Assigned Managed Identity
        // Leave empty to use System-Assigned or default User-Assigned Identity
        public string ManagedIdentityClientId { get; set; }
        
        // For Service Principal authentication (local development)
        public string ClientId { get; set; }
        public string ClientSecret { get; set; }
        public string TenantId { get; set; }
    }
}