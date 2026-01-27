// Program.cs configuration for certificate-based SSO
// Add these registrations to your existing Program.cs

using TravelAgentBot.Bots;
using TravelAgentBot.Services;

var builder = WebApplication.CreateBuilder(args);

// ... existing service registrations ...

// Register certificate-based SSO service (Singleton for certificate caching)
builder.Services.AddSingleton<CertificateSSOService>();

// Register bot (Transient for per-request instances)
builder.Services.AddTransient<IBot, CertificateAuthBot>();

// Add required NuGet packages:
// - Azure.Identity (for DefaultAzureCredential)
// - Azure.Security.KeyVault.Certificates (for CertificateClient)
// - Microsoft.Graph (for Graph API calls)
// - System.IdentityModel.Tokens.Jwt (for JWT signing)

var app = builder.Build();

// ... rest of app configuration ...

app.Run();
