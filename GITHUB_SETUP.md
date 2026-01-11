# GitHub Repository Setup Guide

This guide will help you set up this Travel Agent solution as a public GitHub repository.

## 🎯 Overview

Your solution is now configured to:
- ✅ Exclude secrets and sensitive files from commits (`.gitignore`)
- ✅ Use Managed Identity for secure authentication (no API keys)
- ✅ Include comprehensive documentation
- ✅ Follow GitHub best practices

## 📋 Pre-Setup Checklist

Before creating the GitHub repository, ensure:

- [ ] All code builds successfully
- [ ] `.env.dev.user` file is in `.gitignore` (it is!)
- [ ] `appsettings.Development.json` is in `.gitignore` (it is!)
- [ ] No secrets or API keys are hardcoded in source files
- [ ] Documentation is up to date

## 🚀 Step-by-Step GitHub Setup

### Step 1: Initialize Local Git Repository

Open a terminal in your solution directory (`C:\Dev\travel-agent\`) and run:

```bash
# Initialize git repository
git init

# Add all files
git add .

# Create initial commit
git commit -m "Initial commit: Travel Agent bot with Azure OpenAI and Managed Identity"
```

### Step 2: Create GitHub Repository

#### Option A: Using GitHub CLI (Recommended)

If you have [GitHub CLI](https://cli.github.com/) installed:

```bash
# Login to GitHub (if not already logged in)
gh auth login

# Create public repository and push
gh repo create Microsoft-Teams-travel-agent-azureopenai --public --source=. --remote=origin --push

# Or create private repository
gh repo create Microsoft-Teams-travel-agent-azureopenai --private --source=. --remote=origin --push
```

#### Option B: Using GitHub Web Interface

1. Go to [GitHub](https://github.com) and sign in
2. Click the **+** icon → **New repository**
3. Fill in repository details:
   - **Repository name**: `Microsoft-Teams-travel-agent-azureopenai`
   - **Description**: `AI-powered travel agent for Microsoft Teams using Azure OpenAI and .NET 9`
   - **Visibility**: Choose **Public** or **Private**
   - **DO NOT** initialize with README, .gitignore, or license (we already have these)
4. Click **Create repository**

5. Back in your terminal, add the remote and push:

```bash
# Replace YOUR_USERNAME with your GitHub username
git remote add origin https://github.com/YOUR_USERNAME/Microsoft-Teams-travel-agent-azureopenai.git

# Push to GitHub
git branch -M main
git push -u origin main
```

### Step 3: Configure Repository Settings

On GitHub repository page:

1. **Add Repository Description**
   - Go to repository → Click ⚙️ **Settings**
   - Add description: `AI-powered travel agent for Microsoft Teams using Azure OpenAI and .NET 9`
   - Add topics: `azure-openai`, `microsoft-teams`, `dotnet`, `chatbot`, `azure`, `managed-identity`, `m365-agents`

2. **Enable Discussions** (Optional)
   - Settings → General → Features
   - Check ✅ **Discussions**

3. **Configure Branch Protection** (Recommended)
   - Settings → Branches
   - Click **Add branch protection rule**
   - Branch name pattern: `main`
   - Check ✅ **Require pull request reviews before merging**
   - Check ✅ **Require status checks to pass before merging**
   - Click **Create**

### Step 4: Add GitHub Actions (Optional)

Create `.github/workflows/build.yml` for automated builds:

```yaml
name: Build and Test

on:
  push:
    branches: [ main ]
  pull_request:
    branches: [ main ]

jobs:
  build:
    runs-on: windows-latest

    steps:
    - uses: actions/checkout@v4
    
    - name: Setup .NET
      uses: actions/setup-dotnet@v4
      with:
        dotnet-version: '9.0.x'
    
    - name: Restore dependencies
      run: dotnet restore TravelAgent/TravelAgent.csproj
    
    - name: Build
      run: dotnet build TravelAgent/TravelAgent.csproj --configuration Release --no-restore
    
    - name: Test
      run: dotnet test TravelAgent/TravelAgent.csproj --configuration Release --no-build --verbosity normal
```

### Step 5: Create Additional Files

#### LICENSE File

Create `LICENSE` file with MIT License (or your preferred license):

```bash
# In your terminal
```

```text
MIT License

Copyright (c) 2025 [Your Name]

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
```

#### CONTRIBUTING.md

Create `CONTRIBUTING.md`:

```markdown
# Contributing to Travel Agent

Thank you for your interest in contributing! 🎉

## How to Contribute

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Make your changes
4. Run tests and ensure build succeeds
5. Commit your changes (`git commit -m 'Add amazing feature'`)
6. Push to your branch (`git push origin feature/amazing-feature`)
7. Open a Pull Request

## Development Setup

See [README.md](README.md) for development environment setup.

## Code Standards

- Follow C# coding conventions
- Add XML comments for public APIs
- Include unit tests for new features
- Update documentation for changes
- Ensure `.gitignore` prevents secrets from being committed

## Pull Request Process

1. Update the README.md with details of changes if applicable
2. Ensure all tests pass
3. Request review from maintainers
4. Squash commits before merging

## Code of Conduct

Please be respectful and constructive in all interactions.
```

### Step 6: Commit and Push Additional Files

```bash
git add LICENSE CONTRIBUTING.md .github/
git commit -m "Add LICENSE, CONTRIBUTING, and GitHub Actions workflow"
git push
```

## 🔒 Security Considerations

### Files That Should NEVER Be Committed

The `.gitignore` is configured to exclude:

✅ **Protected Files:**
- `M365Agent/env/.env.*.user` - Contains secrets
- `M365Agent/env/.env.local*` - Local development secrets
- `TravelAgent/appsettings.Development.json` - Development credentials
- All `crypto_*` encrypted values in env files

### How to Verify No Secrets Are Committed

Before pushing, always check:

```bash
# Check what files are staged
git status

# Search for potential secrets (should return nothing)
git grep -i "secret" -- '*.json' '*.cs' '*.yml'
git grep -i "api[_-]key" -- '*.json' '*.cs' '*.yml'
```

### If You Accidentally Commit a Secret

1. **Immediately rotate/delete the secret** in Azure Portal
2. Remove from git history:
```bash
# Install git-filter-repo (if not installed)
# Remove the file from history
git filter-branch --force --index-filter \
  "git rm --cached --ignore-unmatch M365Agent/env/.env.dev.user" \
  --prune-empty --tag-name-filter cat -- --all

# Force push (warning: this rewrites history)
git push origin --force --all
```

3. Create a new secret and update your deployment

## 📊 Repository Structure After Setup

```
Microsoft-Teams-travel-agent-azureopenai/  (GitHub Repository)
├── .github/
│   └── workflows/
│       └── build.yml                   # CI/CD workflow
├── M365Agent/                          # M365 configuration
├── TravelAgent/                        # .NET 9 application
├── .gitignore                          # Git ignore rules ✅
├── README.md                           # Main documentation ✅
├── LICENSE                             # MIT License
├── CONTRIBUTING.md                     # Contribution guide
├── AZURE_AD_AUTH_MIGRATION.md         # Auth migration docs ✅
├── FIX_MANAGED_IDENTITY_ERROR.md      # Troubleshooting ✅
├── DEBUG_MANAGED_IDENTITY.md          # Debug guide ✅
└── QUICK_START.md                      # Quick reference ✅
```

## 🎨 Customize Your Repository

### Add Repository Image/Banner

1. Create an image showcasing your bot (screenshot, diagram, etc.)
2. Upload to `assets/` folder
3. Reference in README:
```markdown
![Travel Agent Bot](./assets/banner.png)
```

### Add Badges

Add status badges to your README:

```markdown
[![Build Status](https://github.com/YOUR_USERNAME/Microsoft-Teams-travel-agent-azureopenai/workflows/Build%20and%20Test/badge.svg)](https://github.com/YOUR_USERNAME/Microsoft-Teams-travel-agent-azureopenai/actions)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![.NET](https://img.shields.io/badge/.NET-9.0-blue.svg)](https://dotnet.microsoft.com/download/dotnet/9.0)
```

## ✅ Final Checklist

Before announcing your repository:

- [ ] Repository is created and pushed
- [ ] README.md is comprehensive and accurate
- [ ] LICENSE file is added
- [ ] CONTRIBUTING.md is added
- [ ] .gitignore properly excludes secrets
- [ ] All documentation files are included
- [ ] Repository description and topics are set
- [ ] Branch protection is configured
- [ ] GitHub Actions workflow is working (if added)
- [ ] No secrets are committed (run git grep check)

## 🎉 You're Done!

Your repository is now ready! Share it with:

```
Repository URL: https://github.com/YOUR_USERNAME/Microsoft-Teams-travel-agent-azureopenai
```

### Next Steps

1. **Add a logo/icon** for your bot
2. **Create a demo video** showing the bot in action
3. **Write a blog post** about your implementation
4. **Share on social media** (LinkedIn, Twitter/X, etc.)
5. **Submit to Microsoft Teams samples** repository

## 📞 Need Help?

If you encounter issues during setup:
1. Check this guide again
2. Review GitHub's [documentation](https://docs.github.com)
3. Open an issue in your repository
4. Ask in [Microsoft Teams Platform Community](https://aka.ms/TeamsPlatform)

---

**Happy Coding! 🚀**
