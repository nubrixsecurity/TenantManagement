# Check if the Microsoft Graph module is installed
Write-Host "Checking for Microsoft Graph module..." -ForegroundColor Yellow
if (-not (Get-Module -ListAvailable -Name Microsoft.Graph)) {
    Write-Host "Microsoft Graph module not found. Installing Microsoft Graph module..." -ForegroundColor Yellow
    Install-Module Microsoft.Graph -Scope CurrentUser -Force -AllowClobber
    Write-Host "Microsoft Graph module installed successfully." -ForegroundColor Green
} else {
    Write-Host "Microsoft Graph module is already installed. Importing necessary components..." -ForegroundColor Yellow
    try {
        Import-Module Microsoft.Graph.Authentication -ErrorAction Stop
        Import-Module Microsoft.Graph.Users -ErrorAction Stop
        Import-Module Microsoft.Graph.Groups -ErrorAction Stop
        Import-Module Microsoft.Graph.Mail -ErrorAction Stop
        Write-Host "Microsoft Graph components imported successfully." -ForegroundColor Green
    } catch {
        Write-Host "Failed to import Microsoft Graph components." -ForegroundColor Red
        exit 1
    }
}

# Check if the Exchange Online Management module is installed
Write-Host "Checking for Exchange Online Management module..." -ForegroundColor Yellow
if (-not (Get-Module -ListAvailable -Name ExchangeOnlineManagement)) {
    Write-Host "Exchange Online Management module not found. Installing Exchange Online Management module..." -ForegroundColor Yellow
    Install-Module ExchangeOnlineManagement -Scope CurrentUser -Force -AllowClobber
    Write-Host "Exchange Online Management module installed successfully." -ForegroundColor Green
} else {
    Write-Host "Exchange Online Management module is already installed. Importing module..." -ForegroundColor Yellow
    try {
        Import-Module ExchangeOnlineManagement -ErrorAction Stop
        Write-Host "Exchange Online Management module imported successfully." -ForegroundColor Green
    } catch {
        Write-Host "Failed to import Exchange Online Management module." -ForegroundColor Red
        exit 1
    }
}
