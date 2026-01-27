// Sample Teams bot implementation using certificate-based SSO
// Shows how to integrate CertificateSSOService in your bot

using Microsoft.Bot.Builder;
using Microsoft.Bot.Builder.Teams;
using Microsoft.Bot.Schema;
using Microsoft.Graph;
using TravelAgentBot.Services;

namespace TravelAgentBot.Bots;

/// <summary>
/// Sample bot showing certificate-based SSO integration
/// </summary>
public class CertificateAuthBot : TeamsActivityHandler
{
    private readonly CertificateSSOService _ssoService;
    private readonly ILogger<CertificateAuthBot> _logger;
    private readonly IConfiguration _configuration;

    public CertificateAuthBot(
        CertificateSSOService ssoService,
        ILogger<CertificateAuthBot> logger,
        IConfiguration configuration)
    {
        _ssoService = ssoService;
        _logger = logger;
        _configuration = configuration;
    }

    protected override async Task OnMessageActivityAsync(
        ITurnContext<IMessageActivity> turnContext,
        CancellationToken cancellationToken)
    {
        var text = turnContext.Activity.Text?.Trim().ToLower();

        _logger.LogInformation("Received message: {Message}", text);

        // Check if certificate-based auth is enabled
        var useCertAuth = _configuration["Azure:UseCertificateAuth"] == "true";

        if (!useCertAuth)
        {
            await turnContext.SendActivityAsync(
                "Certificate-based authentication is not enabled. " +
                "Set Azure:UseCertificateAuth=true to use this feature.",
                cancellationToken: cancellationToken);
            return;
        }

        // Handle user commands
        switch (text)
        {
            case "files":
            case "show files":
            case "my files":
                await ShowUserFilesAsync(turnContext, cancellationToken);
                break;

            case "profile":
            case "my profile":
                await ShowUserProfileAsync(turnContext, cancellationToken);
                break;

            case "help":
            default:
                await ShowHelpAsync(turnContext, cancellationToken);
                break;
        }
    }

    /// <summary>
    /// Show user's OneDrive files using certificate-based SSO
    /// </summary>
    private async Task ShowUserFilesAsync(
        ITurnContext<IMessageActivity> turnContext,
        CancellationToken cancellationToken)
    {
        try
        {
            _logger.LogInformation("Attempting to retrieve user's files");

            // Get user's SSO token from Teams
            var ssoToken = await GetUserSSOTokenAsync(turnContext, cancellationToken);

            if (string.IsNullOrEmpty(ssoToken))
            {
                await turnContext.SendActivityAsync(
                    "Unable to authenticate. Please try again.",
                    cancellationToken: cancellationToken);
                return;
            }

            // Exchange SSO token for Graph token using certificate (OBO)
            var graphToken = await _ssoService.ExchangeTokenForGraphAsync(ssoToken);

            // Create Graph client with token
            var graphClient = CreateGraphClient(graphToken);

            // Get user's recent files
            var driveItems = await graphClient.Me.Drive.Recent()
                .Request()
                .Top(10)
                .GetAsync();

            // Format response
            var message = "📁 **Your recent OneDrive files:**\n\n";

            if (driveItems?.Count > 0)
            {
                foreach (var item in driveItems)
                {
                    var lastModified = item.LastModifiedDateTime?.LocalDateTime.ToString("g") ?? "Unknown";
                    var size = FormatFileSize(item.Size ?? 0);

                    message += $"• **{item.Name}**\n";
                    message += $"  Size: {size}, Modified: {lastModified}\n";
                    if (!string.IsNullOrEmpty(item.WebUrl))
                    {
                        message += $"  [Open in browser]({item.WebUrl})\n";
                    }
                    message += "\n";
                }
            }
            else
            {
                message += "No recent files found.";
            }

            await turnContext.SendActivityAsync(message, cancellationToken: cancellationToken);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error retrieving user files");
            await turnContext.SendActivityAsync(
                $"Sorry, I encountered an error: {ex.Message}",
                cancellationToken: cancellationToken);
        }
    }

    /// <summary>
    /// Show user's profile using certificate-based SSO
    /// </summary>
    private async Task ShowUserProfileAsync(
        ITurnContext<IMessageActivity> turnContext,
        CancellationToken cancellationToken)
    {
        try
        {
            _logger.LogInformation("Attempting to retrieve user's profile");

            // Get user's SSO token from Teams
            var ssoToken = await GetUserSSOTokenAsync(turnContext, cancellationToken);

            if (string.IsNullOrEmpty(ssoToken))
            {
                await turnContext.SendActivityAsync(
                    "Unable to authenticate. Please try again.",
                    cancellationToken: cancellationToken);
                return;
            }

            // Exchange SSO token for Graph token using certificate (OBO)
            var graphToken = await _ssoService.ExchangeTokenForGraphAsync(ssoToken);

            // Create Graph client with token
            var graphClient = CreateGraphClient(graphToken);

            // Get user profile
            var user = await graphClient.Me.Request().GetAsync();

            // Format response
            var message = "👤 **Your Profile:**\n\n";
            message += $"• Name: {user.DisplayName}\n";
            message += $"• Email: {user.Mail ?? user.UserPrincipalName}\n";
            message += $"• Job Title: {user.JobTitle ?? "Not specified"}\n";
            message += $"• Department: {user.Department ?? "Not specified"}\n";
            message += $"• Office Location: {user.OfficeLocation ?? "Not specified"}\n";

            await turnContext.SendActivityAsync(message, cancellationToken: cancellationToken);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error retrieving user profile");
            await turnContext.SendActivityAsync(
                $"Sorry, I encountered an error: {ex.Message}",
                cancellationToken: cancellationToken);
        }
    }

    /// <summary>
    /// Get user's SSO token from Teams
    /// In a real implementation, you would use Teams SSO or Bot Framework token service
    /// </summary>
    private async Task<string?> GetUserSSOTokenAsync(
        ITurnContext turnContext,
        CancellationToken cancellationToken)
    {
        try
        {
            // Option 1: Use Bot Framework UserTokenProvider (if OAuth connection configured)
            if (turnContext.Adapter is IUserTokenProvider tokenProvider)
            {
                var tokenResponse = await tokenProvider.GetUserTokenAsync(
                    turnContext,
                    "GraphConnection",  // Your OAuth connection name
                    null,
                    cancellationToken);

                if (tokenResponse != null)
                {
                    _logger.LogInformation("Retrieved token via Bot Framework");
                    return tokenResponse.Token;
                }
            }

            // Option 2: Teams SSO token (from activity)
            // If Teams SSO is configured, token may be in activity
            // This requires additional configuration in Teams manifest

            _logger.LogWarning("No SSO token available");
            return null;
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error getting SSO token");
            return null;
        }
    }

    /// <summary>
    /// Create Microsoft Graph client with access token
    /// </summary>
    private GraphServiceClient CreateGraphClient(string accessToken)
    {
        return new GraphServiceClient(
            new DelegateAuthenticationProvider(requestMessage =>
            {
                requestMessage.Headers.Authorization =
                    new System.Net.Http.Headers.AuthenticationHeaderValue("Bearer", accessToken);
                return Task.CompletedTask;
            }));
    }

    /// <summary>
    /// Format file size in human-readable format
    /// </summary>
    private static string FormatFileSize(long bytes)
    {
        string[] sizes = { "B", "KB", "MB", "GB", "TB" };
        double len = bytes;
        int order = 0;

        while (len >= 1024 && order < sizes.Length - 1)
        {
            order++;
            len /= 1024;
        }

        return $"{len:0.##} {sizes[order]}";
    }

    /// <summary>
    /// Show help message
    /// </summary>
    private async Task ShowHelpAsync(
        ITurnContext<IMessageActivity> turnContext,
        CancellationToken cancellationToken)
    {
        var message = "**Available Commands:**\n\n";
        message += "• `files` or `my files` - Show your recent OneDrive files\n";
        message += "• `profile` or `my profile` - Show your user profile\n";
        message += "• `help` - Show this help message\n\n";
        message += "This bot uses **certificate-based authentication** for secure access to your Microsoft 365 data.";

        await turnContext.SendActivityAsync(message, cancellationToken: cancellationToken);
    }
}
