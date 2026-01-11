# Verify GitHub Readiness Script
# This script checks if your repository is ready to be pushed to GitHub

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  GitHub Readiness Check" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

$allPassed = $true

# Check 1: Required files exist
Write-Host "1. Checking required files..." -ForegroundColor Yellow
$requiredFiles = @(
    ".gitignore",
    "LICENSE",
    "CONTRIBUTING.md",
    "README.md",
    "GITHUB_SETUP.md",
    "setup-github.ps1",
    ".github\workflows\build.yml"
)

foreach ($file in $requiredFiles) {
    if (Test-Path $file) {
        Write-Host "   ? $file" -ForegroundColor Green
    } else {
        Write-Host "   ? $file MISSING!" -ForegroundColor Red
        $allPassed = $false
    }
}

# Check 2: Build succeeds
Write-Host ""
Write-Host "2. Checking if project builds..." -ForegroundColor Yellow
$buildResult = dotnet build TravelAgent/TravelAgent.csproj --configuration Release --nologo --verbosity quiet 2>&1

if ($LASTEXITCODE -eq 0) {
    Write-Host "   ? Build successful" -ForegroundColor Green
} else {
    Write-Host "   ? Build failed!" -ForegroundColor Red
    Write-Host "   $buildResult" -ForegroundColor Red
    $allPassed = $false
}

# Check 3: No secrets in code
Write-Host ""
Write-Host "3. Checking for secrets in code..." -ForegroundColor Yellow

$secretPatterns = @(
    @{Pattern = "api[_-]key\s*=\s*['\`"][^'\`"]"; Name = "API Keys"},
    @{Pattern = "client[_-]secret\s*=\s*['\`"][^'\`"]"; Name = "Client Secrets"},
    @{Pattern = "password\s*=\s*['\`"][^'\`"]"; Name = "Passwords"},
    @{Pattern = "sk-[a-zA-Z0-9]{32,}"; Name = "OpenAI Keys"}
)

$foundSecrets = $false
foreach ($check in $secretPatterns) {
    $files = Get-ChildItem -Path . -Include *.cs,*.json,*.yml,*.yaml -Recurse -ErrorAction SilentlyContinue |
        Where-Object { $_.FullName -notmatch "\\bin\\|\\obj\\|\\.vs\\|\\.git\\" }
    
    foreach ($file in $files) {
        $content = Get-Content $file.FullName -Raw -ErrorAction SilentlyContinue
        if ($content -match $check.Pattern) {
            Write-Host "   ? $($check.Name) found in: $($file.FullName)" -ForegroundColor Red
            $foundSecrets = $true
        }
    }
}

if (-not $foundSecrets) {
    Write-Host "   ? No secrets detected" -ForegroundColor Green
} else {
    Write-Host "   ? Secrets detected! Remove before committing!" -ForegroundColor Red
    $allPassed = $false
}

# Check 4: Sensitive files are in .gitignore
Write-Host ""
Write-Host "4. Checking .gitignore coverage..." -ForegroundColor Yellow

$sensitivePatterns = @(
    "*.user",
    ".env.*.user",
    ".env.local",
    "appsettings.Development.json"
)

$gitignoreContent = Get-Content .gitignore -Raw

$allCovered = $true
foreach ($pattern in $sensitivePatterns) {
    if ($gitignoreContent -match [regex]::Escape($pattern)) {
        Write-Host "   ? $pattern is ignored" -ForegroundColor Green
    } else {
        Write-Host "   ? $pattern might not be ignored" -ForegroundColor Yellow
    }
}

# Check 5: Sensitive files exist but are ignored
Write-Host ""
Write-Host "5. Checking sensitive files are properly ignored..." -ForegroundColor Yellow

$sensitiveFiles = @(
    "M365Agent\env\.env.dev.user",
    "TravelAgent\appsettings.Development.json"
)

foreach ($file in $sensitiveFiles) {
    if (Test-Path $file) {
        # Check if it would be committed
        $gitStatus = git status --porcelain $file 2>$null
        if ([string]::IsNullOrWhiteSpace($gitStatus)) {
            Write-Host "   ? $file exists and is ignored" -ForegroundColor Green
        } else {
            Write-Host "   ? $file exists but is NOT ignored!" -ForegroundColor Red
            $allPassed = $false
        }
    } else {
        Write-Host "   - $file doesn't exist (OK)" -ForegroundColor Gray
    }
}

# Check 6: Git configuration
Write-Host ""
Write-Host "6. Checking Git configuration..." -ForegroundColor Yellow

$gitUserName = git config user.name 2>$null
$gitUserEmail = git config user.email 2>$null

if ($gitUserName -and $gitUserEmail) {
    Write-Host "   ? Git user configured: $gitUserName <$gitUserEmail>" -ForegroundColor Green
} else {
    Write-Host "   ? Git user not configured (optional)" -ForegroundColor Yellow
    Write-Host "     Run: git config --global user.name 'Your Name'" -ForegroundColor Gray
    Write-Host "     Run: git config --global user.email 'your.email@example.com'" -ForegroundColor Gray
}

# Check 7: Documentation complete
Write-Host ""
Write-Host "7. Checking documentation..." -ForegroundColor Yellow

$docFiles = @(
    "README.md",
    "AZURE_AD_AUTH_MIGRATION.md",
    "FIX_MANAGED_IDENTITY_ERROR.md",
    "DEBUG_MANAGED_IDENTITY.md",
    "QUICK_START.md",
    "GITHUB_SETUP.md",
    "PUSH_TO_GITHUB.md"
)

foreach ($doc in $docFiles) {
    if (Test-Path $doc) {
        $size = (Get-Item $doc).Length
        if ($size -gt 100) {
            Write-Host "   ? $doc ($([math]::Round($size/1KB, 1)) KB)" -ForegroundColor Green
        } else {
            Write-Host "   ? $doc is very small" -ForegroundColor Yellow
        }
    } else {
        Write-Host "   ? $doc MISSING!" -ForegroundColor Red
        $allPassed = $false
    }
}

# Final result
Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan

if ($allPassed) {
    Write-Host "  ? ALL CHECKS PASSED! ??" -ForegroundColor Green
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Your repository is ready to be pushed to GitHub!" -ForegroundColor Green
    Write-Host ""
    Write-Host "Next step: Run .\setup-github.ps1 to push to GitHub" -ForegroundColor Cyan
} else {
    Write-Host "  ? SOME CHECKS FAILED!" -ForegroundColor Red
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Please fix the issues above before pushing to GitHub." -ForegroundColor Red
}

Write-Host ""
