# Required NuGet Packages for Certificate-Based SSO

## Add these packages to your M365Agent.csproj

```xml
<ItemGroup>
  <!-- Azure Identity and Key Vault -->
  <PackageReference Include="Azure.Identity" Version="1.10.4" />
  <PackageReference Include="Azure.Security.KeyVault.Certificates" Version="4.5.1" />
  
  <!-- JWT Token Handling -->
  <PackageReference Include="System.IdentityModel.Tokens.Jwt" Version="7.1.2" />
  
  <!-- Microsoft Graph -->
  <PackageReference Include="Microsoft.Graph" Version="5.42.0" />
  
  <!-- Bot Framework (if not already added) -->
  <PackageReference Include="Microsoft.Bot.Builder" Version="4.21.2" />
  <PackageReference Include="Microsoft.Bot.Builder.Integration.AspNet.Core" Version="4.21.2" />
</ItemGroup>
```

## Or install via dotnet CLI

```bash
cd M365Agent

# Azure packages
dotnet add package Azure.Identity --version 1.10.4
dotnet add package Azure.Security.KeyVault.Certificates --version 4.5.1

# JWT package
dotnet add package System.IdentityModel.Tokens.Jwt --version 7.1.2

# Microsoft Graph
dotnet add package Microsoft.Graph --version 5.42.0
```

## Verify Installation

```bash
dotnet list package
```

Expected output should include all packages above.
