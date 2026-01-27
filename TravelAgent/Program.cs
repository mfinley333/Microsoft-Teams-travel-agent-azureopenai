using Azure.AI.OpenAI;
using Azure;
using Azure.Identity;
using TravelAgent;
using Microsoft.Agents.Hosting.AspNetCore;
using Microsoft.Agents.Builder.App;
using Microsoft.Agents.Builder;
using Microsoft.Agents.Storage;
using Microsoft.Extensions.AI;


var builder = WebApplication.CreateBuilder(args);

builder.Services.AddControllers();
builder.Services.AddHttpClient("WebClient", client => client.Timeout = TimeSpan.FromSeconds(600));
builder.Services.AddHttpContextAccessor();
builder.Logging.AddConsole();

var config = builder.Configuration.Get<ConfigOptions>();

// Configure services without calling BuildServiceProvider
builder.Services.AddSingleton(serviceProvider =>
{
    var loggerFactory = serviceProvider.GetRequiredService<ILoggerFactory>();
    var log = loggerFactory.CreateLogger("AzureOpenAI");
    
    try
    {
        Azure.Core.TokenCredential credential;
        
        log.LogInformation("Configuring Azure OpenAI authentication...");
        log.LogInformation("UseManagedIdentity: {UseManagedIdentity}", config.Azure.UseManagedIdentity);
        log.LogInformation("OpenAI Endpoint: {Endpoint}", config.Azure.OpenAIEndpoint);
        log.LogInformation("Deployment Name: {DeploymentName}", config.Azure.OpenAIDeploymentName);
        
        if (config.Azure.UseManagedIdentity)
        {
            log.LogInformation("Using Managed Identity for Azure OpenAI authentication");
            
            // Use DefaultAzureCredential with options for better debugging
            var credentialOptions = new DefaultAzureCredentialOptions
            {
                ExcludeEnvironmentCredential = false,
                ExcludeManagedIdentityCredential = false,
                // ExcludeSharedTokenCacheCredential removed - property is obsolete
                ExcludeVisualStudioCredential = true,
                ExcludeVisualStudioCodeCredential = true,
                ExcludeAzureCliCredential = true,
                ExcludeAzurePowerShellCredential = true,
                ExcludeInteractiveBrowserCredential = true
            };
            
            // If a specific Managed Identity Client ID is provided, use it
            if (!string.IsNullOrEmpty(config.Azure.ManagedIdentityClientId))
            {
                log.LogInformation("Using User-Assigned Managed Identity with Client ID: {ClientId}", 
                    config.Azure.ManagedIdentityClientId);
                credentialOptions.ManagedIdentityClientId = config.Azure.ManagedIdentityClientId;
            }
            else
            {
                log.LogInformation("Using System-Assigned or default User-Assigned Managed Identity");
            }
            
            credential = new DefaultAzureCredential(credentialOptions);
        }
        else
        {
            log.LogInformation("Using Client Secret for Azure OpenAI authentication");
            
            if (string.IsNullOrEmpty(config.Azure.ClientId) || 
                string.IsNullOrEmpty(config.Azure.ClientSecret) || 
                string.IsNullOrEmpty(config.Azure.TenantId))
            {
                throw new InvalidOperationException(
                    "When UseManagedIdentity is false, ClientId, ClientSecret, and TenantId must be provided");
            }
            
            credential = new ClientSecretCredential(
                config.Azure.TenantId,
                config.Azure.ClientId,
                config.Azure.ClientSecret);
        }
        
        log.LogInformation("Creating Azure OpenAI client...");
        var client = new AzureOpenAIClient(new Uri(config.Azure.OpenAIEndpoint), credential)
            .GetChatClient(config.Azure.OpenAIDeploymentName)
            .AsIChatClient();
        
        log.LogInformation("Azure OpenAI client created successfully");
        return client;
    }
    catch (Exception ex)
    {
        log.LogError(ex, "Failed to create Azure OpenAI client. Error: {ErrorMessage}", ex.Message);
        throw;
    }
});

// Register the TravelAgent
builder.Services.AddTransient<TravelAgent.Bot.TravelAgentBot>();

// Add AspNet token validation
builder.Services.AddBotAspNetAuthentication(builder.Configuration);

// Register IStorage.  For development, MemoryStorage is suitable.
// For production Agents, persisted storage should be used so
// that state survives Agent restarts, and operate correctly
// in a cluster of Agent instances.
builder.Services.AddSingleton<IStorage, MemoryStorage>();

// Add AgentApplicationOptions from config.
builder.AddAgentApplicationOptions();

// Add AgentApplicationOptions.  This will use DI'd services and IConfiguration for construction.
builder.Services.AddTransient<AgentApplicationOptions>();

// Add the bot (which is transient)
builder.AddAgent<TravelAgent.Bot.TravelAgentBot>();

var app = builder.Build();

if (app.Environment.IsDevelopment())
{
    app.UseDeveloperExceptionPage();
}
app.UseStaticFiles();

app.UseRouting();

app.UseAuthentication();
app.UseAuthorization();

app.MapPost("/api/messages", async (HttpRequest request, HttpResponse response, IAgentHttpAdapter adapter, IAgent agent, CancellationToken cancellationToken) =>
{
    await adapter.ProcessAsync(request, response, agent, cancellationToken);
});

if (app.Environment.IsDevelopment())
{
    app.MapGet("/", () => "Travel Agent");
    app.UseDeveloperExceptionPage();
    app.MapControllers().AllowAnonymous();
}
else
{
    app.MapControllers();
}

app.Run();

