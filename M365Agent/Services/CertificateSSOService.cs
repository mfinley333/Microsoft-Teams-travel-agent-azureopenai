// Certificate-based SSO service for Teams bot
// Uses certificate from Azure Key Vault (accessed via Managed Identity) instead of client secret
// Implements On-Behalf-Of (OBO) flow for user-delegated permissions

using System.IdentityModel.Tokens.Jwt;
using System.Security.Claims;
using System.Security.Cryptography.X509Certificates;
using System.Text.Json;
using System.Text.Json.Serialization;
using Azure.Identity;
using Azure.Security.KeyVault.Certificates;
using Microsoft.IdentityModel.Tokens;

namespace TravelAgentBot.Services;

/// <summary>
/// Handles certificate-based SSO authentication using Azure Key Vault
/// </summary>
public class CertificateSSOService
{
    private readonly IConfiguration _configuration;
    private readonly ILogger<CertificateSSOService> _logger;
    private readonly DefaultAzureCredential _credential;
    private X509Certificate2? _cachedCertificate;
    private DateTime _certificateCacheExpiry;

    public CertificateSSOService(
        IConfiguration configuration,
        ILogger<CertificateSSOService> logger)
    {
        _configuration = configuration;
        _logger = logger;
        _credential = new DefaultAzureCredential();
        _certificateCacheExpiry = DateTime.MinValue;
    }

    /// <summary>
    /// Get certificate from Azure Key Vault (with caching)
    /// </summary>
    public async Task<X509Certificate2> GetCertificateFromKeyVaultAsync()
    {
        // Return cached certificate if still valid
        if (_cachedCertificate != null && DateTime.UtcNow < _certificateCacheExpiry)
        {
            _logger.LogDebug("Using cached certificate");
            return _cachedCertificate;
        }

        var keyVaultUrl = _configuration["Azure:KeyVaultUrl"];
        var certificateName = _configuration["Azure:SSOCertificateName"];

        if (string.IsNullOrEmpty(keyVaultUrl))
        {
            throw new InvalidOperationException("Azure:KeyVaultUrl configuration is missing");
        }

        if (string.IsNullOrEmpty(certificateName))
        {
            throw new InvalidOperationException("Azure:SSOCertificateName configuration is missing");
        }

        _logger.LogInformation("Retrieving certificate '{CertificateName}' from Key Vault '{KeyVaultUrl}'",
            certificateName, keyVaultUrl);

        try
        {
            var client = new CertificateClient(new Uri(keyVaultUrl), _credential);

            // Download certificate with private key
            var certificateResponse = await client.DownloadCertificateAsync(certificateName);
            _cachedCertificate = certificateResponse.Value;

            // Cache certificate for 1 hour
            _certificateCacheExpiry = DateTime.UtcNow.AddHours(1);

            _logger.LogInformation("Successfully retrieved certificate from Key Vault");
            return _cachedCertificate;
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Failed to retrieve certificate from Key Vault");
            throw;
        }
    }

    /// <summary>
    /// Exchange user's SSO token for a Graph API access token using OBO flow with certificate
    /// </summary>
    public async Task<string> ExchangeTokenForGraphAsync(string userSsoToken)
    {
        var tenantId = _configuration["Azure:TenantId"];
        var clientId = _configuration["Azure:ClientId"];

        if (string.IsNullOrEmpty(tenantId))
        {
            throw new InvalidOperationException("Azure:TenantId configuration is missing");
        }

        if (string.IsNullOrEmpty(clientId))
        {
            throw new InvalidOperationException("Azure:ClientId configuration is missing");
        }

        _logger.LogInformation("Exchanging SSO token for Graph token using OBO flow");

        try
        {
            // Get certificate from Key Vault
            var certificate = await GetCertificateFromKeyVaultAsync();

            // Create client assertion (JWT signed with certificate)
            var clientAssertion = CreateClientAssertion(clientId, tenantId, certificate);

            // Call Azure AD token endpoint with OBO grant
            var tokenEndpoint = $"https://login.microsoftonline.com/{tenantId}/oauth2/v2.0/token";

            using var httpClient = new HttpClient();
            var requestBody = new FormUrlEncodedContent(new Dictionary<string, string>
            {
                { "grant_type", "urn:ietf:params:oauth:grant-type:jwt-bearer" },
                { "client_id", clientId },
                { "client_assertion_type", "urn:ietf:params:oauth:client-assertion-type:jwt-bearer" },
                { "client_assertion", clientAssertion },
                { "assertion", userSsoToken },
                { "scope", "https://graph.microsoft.com/.default" },
                { "requested_token_use", "on_behalf_of" }
            });

            var response = await httpClient.PostAsync(tokenEndpoint, requestBody);
            var content = await response.Content.ReadAsStringAsync();

            if (!response.IsSuccessStatusCode)
            {
                _logger.LogError("Token exchange failed. Status: {StatusCode}, Response: {Response}",
                    response.StatusCode, content);
                throw new InvalidOperationException($"Token exchange failed: {content}");
            }

            var tokenResponse = JsonSerializer.Deserialize<TokenResponse>(content);

            if (tokenResponse?.AccessToken == null)
            {
                throw new InvalidOperationException("Token exchange returned null access token");
            }

            _logger.LogInformation("Successfully exchanged SSO token for Graph token");
            return tokenResponse.AccessToken;
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Failed to exchange SSO token for Graph token");
            throw;
        }
    }

    /// <summary>
    /// Create a client assertion JWT signed with certificate
    /// </summary>
    private string CreateClientAssertion(string clientId, string tenantId, X509Certificate2 certificate)
    {
        var now = DateTimeOffset.UtcNow;

        // Create JWT claims
        var claims = new[]
        {
            new Claim("aud", $"https://login.microsoftonline.com/{tenantId}/oauth2/v2.0/token"),
            new Claim("iss", clientId),
            new Claim("sub", clientId),
            new Claim("jti", Guid.NewGuid().ToString()),
            new Claim("exp", now.AddMinutes(10).ToUnixTimeSeconds().ToString()),
            new Claim("nbf", now.ToUnixTimeSeconds().ToString())
        };

        // Sign JWT with certificate
        var credentials = new X509SigningCredentials(certificate);
        var header = new JwtHeader(credentials);
        var payload = new JwtPayload(claims);
        var token = new JwtSecurityToken(header, payload);

        var handler = new JwtSecurityTokenHandler();
        var jwt = handler.WriteToken(token);

        _logger.LogDebug("Created client assertion JWT");
        return jwt;
    }
}

/// <summary>
/// Token response from Azure AD
/// </summary>
public class TokenResponse
{
    [JsonPropertyName("access_token")]
    public string? AccessToken { get; set; }

    [JsonPropertyName("token_type")]
    public string? TokenType { get; set; }

    [JsonPropertyName("expires_in")]
    public int ExpiresIn { get; set; }

    [JsonPropertyName("scope")]
    public string? Scope { get; set; }

    [JsonPropertyName("refresh_token")]
    public string? RefreshToken { get; set; }
}
