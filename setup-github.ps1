# GitHub Repository Setup Script for Travel Agent Bot
# Run this script to initialize and push your repository to GitHub

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  Travel Agent Bot - GitHub Setup" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Check if git is installed
Write-Host "Checking prerequisites..." -ForegroundColor Yellow
if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
    Write-Host "ERROR: Git is not installed!" -ForegroundColor Red
    Write-Host "Please install Git from: https://git-scm.com/downloads" -ForegroundColor Red
    exit 1
}

# Check if we're in the right directory
if (-not (Test-Path "TravelAgent/TravelAgent.csproj")) {
    Write-Host "ERROR: Run this script from the solution root directory!" -ForegroundColor Red
    exit 1
}

Write-Host "✓ Prerequisites OK" -ForegroundColor Green
Write-Host ""

# Check if git is already initialized
if (Test-Path ".git") {
    Write-Host "WARNING: Git repository already initialized!" -ForegroundColor Yellow
    $continue = Read-Host "Do you want to continue? (y/N)"
    if ($continue -ne "y") {
        exit 0
    }
} else {
    # Initialize git repository
    Write-Host "Initializing git repository..." -ForegroundColor Yellow
    git init
    Write-Host "✓ Git repository initialized" -ForegroundColor Green
}

# Check for secrets before committing
Write-Host ""
Write-Host "Checking for secrets in code..." -ForegroundColor Yellow

$secretPatterns = @(
    "api[_-]key",
    "client[_-]secret",
    "password",
    "bearer\s+[a-zA-Z0-9]",
    "crypto_[a-f0-9]+"
)

$foundSecrets = $false
foreach ($pattern in $secretPatterns) {
    $matches = git grep -i -E $pattern -- "*.cs" "*.json" "*.yml" 2>$null
    if ($matches) {
        Write-Host "⚠ WARNING: Potential secrets found matching pattern: $pattern" -ForegroundColor Red
        Write-Host $matches
        $foundSecrets = $true
    }
}

if ($foundSecrets) {
    Write-Host ""
    Write-Host "ERROR: Potential secrets detected!" -ForegroundColor Red
    Write-Host "Please review and remove secrets before committing." -ForegroundColor Red
    $continue = Read-Host "Continue anyway? (y/N)"
    if ($continue -ne "y") {
        exit 1
    }
} else {
    Write-Host "✓ No secrets detected" -ForegroundColor Green
}

# Get GitHub username
Write-Host ""
Write-Host "GitHub Configuration" -ForegroundColor Cyan
Write-Host "===================" -ForegroundColor Cyan
$githubUsername = Read-Host "Enter your GitHub username"

if ([string]::IsNullOrWhiteSpace($githubUsername)) {
    Write-Host "ERROR: GitHub username is required!" -ForegroundColor Red
    exit 1
}

# Get repository name
$defaultRepoName = "Microsoft-Teams-travel-agent-azureopenai"
$repoName = Read-Host "Enter repository name (default: $defaultRepoName)"
if ([string]::IsNullOrWhiteSpace($repoName)) {
    $repoName = $defaultRepoName
}

# Ask if public or private
Write-Host ""
Write-Host "Repository visibility:" -ForegroundColor Yellow
Write-Host "1. Public (anyone can see)"
Write-Host "2. Private (only you and collaborators)"
$visibility = Read-Host "Choose (1 or 2)"

$isPublic = $visibility -eq "1"
$visibilityText = if ($isPublic) { "public" } else { "private" }

# Confirmation
Write-Host ""
Write-Host "Review Settings:" -ForegroundColor Cyan
Write-Host "===============" -ForegroundColor Cyan
Write-Host "GitHub Username: $githubUsername"
Write-Host "Repository Name: $repoName"
Write-Host "Visibility: $visibilityText"
Write-Host ""

$confirm = Read-Host "Proceed with these settings? (y/N)"
if ($confirm -ne "y") {
    Write-Host "Setup cancelled." -ForegroundColor Yellow
    exit 0
}

# Add files to git
Write-Host ""
Write-Host "Adding files to git..." -ForegroundColor Yellow
git add .

# Create initial commit
Write-Host "Creating initial commit..." -ForegroundColor Yellow
git commit -m "Initial commit: Travel Agent bot with Azure OpenAI and Managed Identity

- .NET 9 bot application with Azure OpenAI integration
- Uses Managed Identity for secure authentication
- Microsoft Teams integration via M365 Agents Toolkit
- Comprehensive documentation and setup guides
- Configured for secure deployment to Azure"

Write-Host "✓ Initial commit created" -ForegroundColor Green

# Set main branch
Write-Host "Setting main branch..." -ForegroundColor Yellow
git branch -M main

# Check if gh CLI is available
$hasGhCli = Get-Command gh -ErrorAction SilentlyContinue

if ($hasGhCli) {
    Write-Host ""
    Write-Host "GitHub CLI detected. Using gh to create repository..." -ForegroundColor Yellow
    
    # Check if logged in
    $ghStatus = gh auth status 2>&1
    if ($LASTEXITCODE -ne 0) {
        Write-Host "Not logged in to GitHub CLI. Please login..." -ForegroundColor Yellow
        gh auth login
    }
    
    # Create repository
    $ghVisibility = if ($isPublic) { "--public" } else { "--private" }
    
    Write-Host "Creating GitHub repository..." -ForegroundColor Yellow
    gh repo create $repoName $ghVisibility --source=. --remote=origin --description="AI-powered travel agent for Microsoft Teams using Azure OpenAI and .NET 9"
    
    if ($LASTEXITCODE -eq 0) {
        Write-Host "✓ Repository created successfully!" -ForegroundColor Green
        
        # Push to GitHub
        Write-Host "Pushing to GitHub..." -ForegroundColor Yellow
        git push -u origin main
        
        if ($LASTEXITCODE -eq 0) {
            Write-Host "✓ Code pushed successfully!" -ForegroundColor Green
            Write-Host ""
            Write-Host "========================================" -ForegroundColor Green
            Write-Host "  Setup Complete! 🎉" -ForegroundColor Green
            Write-Host "========================================" -ForegroundColor Green
            Write-Host ""
            Write-Host "Your repository is available at:" -ForegroundColor Cyan
            Write-Host "https://github.com/$githubUsername/$repoName" -ForegroundColor Cyan
            Write-Host ""
            Write-Host "Next steps:" -ForegroundColor Yellow
            Write-Host "1. Review your repository on GitHub"
            Write-Host "2. Add topics/tags to your repository"
            Write-Host "3. Enable GitHub Discussions (optional)"
            Write-Host "4. Configure branch protection rules"
            Write-Host "5. Share your project!"
        } else {
            Write-Host "ERROR: Failed to push to GitHub!" -ForegroundColor Red
        }
    } else {
        Write-Host "ERROR: Failed to create repository!" -ForegroundColor Red
    }
    
} else {
    # Manual instructions
    Write-Host ""
    Write-Host "GitHub CLI not found. Manual setup required." -ForegroundColor Yellow
    Write-Host ""
    Write-Host "Next steps:" -ForegroundColor Cyan
    Write-Host "==========" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "1. Go to https://github.com/new" -ForegroundColor Yellow
    Write-Host "2. Create a new repository with these settings:" -ForegroundColor Yellow
    Write-Host "   - Repository name: $repoName"
    Write-Host "   - Visibility: $visibilityText"
    Write-Host "   - DO NOT initialize with README, .gitignore, or license"
    Write-Host ""
    Write-Host "3. After creating, run these commands:" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "   git remote add origin https://github.com/$githubUsername/$repoName.git" -ForegroundColor White
    Write-Host "   git push -u origin main" -ForegroundColor White
    Write-Host ""
    Write-Host "4. Your repository will be available at:" -ForegroundColor Cyan
    Write-Host "   https://github.com/$githubUsername/$repoName" -ForegroundColor Cyan
}

Write-Host ""
Write-Host "For detailed instructions, see GITHUB_SETUP.md" -ForegroundColor Cyan
