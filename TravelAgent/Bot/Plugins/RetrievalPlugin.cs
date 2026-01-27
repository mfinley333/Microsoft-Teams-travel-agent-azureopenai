using System.ComponentModel;
using Microsoft.Agents.Builder.App;
using Microsoft.Agents.Builder;
using Microsoft.Graph;
using Microsoft.Graph.Models;
using Microsoft.Graph.Search.Query;
using Microsoft.Kiota.Abstractions.Authentication;
using Microsoft.Identity.Client;
using Microsoft.Extensions.Configuration;
using Newtonsoft.Json.Linq;

namespace TravelAgent.Bot.Plugins
{
    public class RetrievalPlugin
    {
        private readonly AgentApplication _app;
        private readonly ITurnContext _turnContext;
        private readonly IConfiguration _configuration;

        public RetrievalPlugin(AgentApplication app, ITurnContext turnContext, IConfiguration configuration)
        {
            _app = app;
            _turnContext = turnContext;
            _configuration = configuration;
        }

        /// <summary>
        /// Retrieve travel policies about expenses using Microsoft Graph Search API.
        /// Uses SSO token from Teams and On-Behalf-Of flow for secure Graph access.
        /// </summary>
        /// <param name="userquery">The user query as a string</param>
        /// <returns></returns>
        [Description("This function searches OneDrive for travel policies about expenses and reimbursements, flight booking, ground transportation, hotel accommodations. It accepts user query as input and returns relevant text and file links.")]
        public async Task<string> BuildRetrievalAsync(string userquery)
        {
            try
            {
                // Get user's SSO token from Teams activity
                string userToken = await GetUserSsoTokenAsync();
                
                if (string.IsNullOrEmpty(userToken))
                {
                    return "Unable to authenticate. Please ensure you're signed in to Teams.";
                }
                
                // Exchange user token for Graph token using On-Behalf-Of (OBO) flow
                string accessToken = await GetGraphTokenViaOboAsync(userToken);
                
                // Create Graph client with token
                var authProvider = new BaseBearerTokenAuthenticationProvider(
                    new StaticTokenProvider(accessToken));
                var graphClient = new GraphServiceClient(authProvider);

                // Create search request using Microsoft Graph Search API
                var searchRequest = new Microsoft.Graph.Search.Query.QueryPostRequestBody
                {
                    Requests = new List<SearchRequest>
                    {
                        new SearchRequest
                        {
                            EntityTypes = new List<EntityType?> { EntityType.DriveItem },
                            Query = new SearchQuery
                            {
                                QueryString = userquery
                            },
                            From = 0,
                            Size = 10,
                            Fields = new List<string> 
                            { 
                                "name", 
                                "path", 
                                "lastModifiedDateTime", 
                                "webUrl",
                                "contentclass",
                                "author"
                            }
                        }
                    }
                };

                // Execute search
                var searchResults = await graphClient.Search.Query.PostAsQueryPostResponseAsync(searchRequest);

                // Process and format results
                if (searchResults?.Value != null && searchResults.Value.Any())
                {
                    var formattedResults = new List<object>();
                    
                    foreach (var resultContainer in searchResults.Value)
                    {
                        if (resultContainer.HitsContainers != null)
                        {
                            foreach (var hitsContainer in resultContainer.HitsContainers)
                            {
                                if (hitsContainer.Hits != null)
                                {
                                    foreach (var hit in hitsContainer.Hits)
                                    {
                                        var resource = hit.Resource as DriveItem;
                                        if (resource != null)
                                        {
                                            formattedResults.Add(new
                                            {
                                                Name = resource.Name,
                                                WebUrl = resource.WebUrl,
                                                LastModified = resource.LastModifiedDateTime,
                                                Path = resource.ParentReference?.Path,
                                                Author = resource.CreatedBy?.User?.DisplayName,
                                                Score = hit.Rank
                                            });
                                        }
                                    }
                                }
                            }
                        }
                    }

                    return System.Text.Json.JsonSerializer.Serialize(new
                    {
                        Query = userquery,
                        ResultCount = formattedResults.Count,
                        Results = formattedResults
                    }, new System.Text.Json.JsonSerializerOptions { WriteIndented = true });
                }

                return System.Text.Json.JsonSerializer.Serialize(new
                {
                    Query = userquery,
                    ResultCount = 0,
                    Message = "No results found for your query."
                });
            }
            catch (Exception ex)
            {
                // Log or inspect the exception and return details for debugging
                return $"Exception: {ex.GetType().Name} - {ex.Message}\nStackTrace: {ex.StackTrace}";
            }
        }

        /// <summary>
        /// Extracts the user's SSO token from the Teams activity.
        /// Teams sends the token through SSO when webApplicationInfo is configured.
        /// </summary>
        private async Task<string> GetUserSsoTokenAsync()
        {
            var activity = _turnContext.Activity;
            
            // Try to get token from activity value (token exchange)
            if (activity.Name == "signin/tokenExchange" && activity.Value != null)
            {
                var tokenExchangeRequest = ((JObject)activity.Value).ToObject<TokenExchangeRequest>();
                if (!string.IsNullOrEmpty(tokenExchangeRequest?.Token))
                {
                    return tokenExchangeRequest.Token;
                }
            }
            
            // Try to get from channel data (Teams SSO)
            if (activity.ChannelData is JObject channelData)
            {
                var ssoToken = channelData["ssoToken"]?.ToString();
                if (!string.IsNullOrEmpty(ssoToken))
                {
                    return ssoToken;
                }
            }
            
            // For this implementation, we expect the token to be available from SSO
            // If not available, the bot needs proper SSO configuration in Teams manifest
            return await Task.FromResult<string>(null);
        }

        /// <summary>
        /// Exchange user's SSO token for Microsoft Graph token using On-Behalf-Of (OBO) flow.
        /// This enables the bot to call Graph APIs with the user's delegated permissions.
        /// </summary>
        private async Task<string> GetGraphTokenViaOboAsync(string userToken)
        {
            string clientId = _configuration["AAD_APP_CLIENT_ID"];
            string tenantId = _configuration["AAD_APP_TENANT_ID"];
            string clientSecret = _configuration["AAD_APP_CLIENT_SECRET"];
            
            if (string.IsNullOrEmpty(clientId) || string.IsNullOrEmpty(tenantId) || string.IsNullOrEmpty(clientSecret))
            {
                throw new InvalidOperationException("AAD configuration is missing. Ensure AAD_APP_CLIENT_ID, AAD_APP_TENANT_ID, and AAD_APP_CLIENT_SECRET are configured.");
            }
            
            // Build confidential client application for OBO flow
            var app = ConfidentialClientApplicationBuilder
                .Create(clientId)
                .WithAuthority($"https://login.microsoftonline.com/{tenantId}")
                .WithClientSecret(clientSecret) // Retrieved from KeyVault via App Service configuration
                .Build();
            
            var userAssertion = new UserAssertion(userToken);
            
            // Request Graph scopes with user's permissions
            string[] scopes = new[] 
            { 
                "https://graph.microsoft.com/User.Read",
                "https://graph.microsoft.com/Files.Read",
                "https://graph.microsoft.com/Sites.Read.All"
            };
            
            try
            {
                var result = await app.AcquireTokenOnBehalfOf(scopes, userAssertion)
                    .ExecuteAsync();
                
                return result.AccessToken;
            }
            catch (MsalException ex)
            {
                throw new InvalidOperationException($"OBO token exchange failed: {ex.Message}. Ensure admin consent is granted for Graph API scopes.", ex);
            }
        }

        /// <summary>
        /// Simple class to deserialize token exchange request
        /// </summary>
        private class TokenExchangeRequest
        {
            public string Token { get; set; }
            public string Id { get; set; }
        }
    }
}
