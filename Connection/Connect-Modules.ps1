Write-Host "Attempting to connect to Exchange Online..." -ForegroundColor Yellow
try{
    Connect-ExchangeOnline -ShowBanner:$false
    Write-Host "Connected to Exchange Online successfully!" -ForegroundColor Green

    try {
        Write-Host "Connecting to Microsoft Graph" -ForegroundColor Yellow
        $scopes = @("Group.ReadWrite.All", "User.ReadWrite.All", "Directory.ReadWrite.All","Directory.AccessAsUser.All")
        Connect-MgGraph -Scopes $scopes

        Write-Host "Connected to Microsoft Graph successfully!" -ForegroundColor Green

    } catch {
        Write-Host "Failed to connect to Microsoft Graph." -ForegroundColor Red
        exit 1
    }
} catch {
    Write-Host  "Failed to connect to Exchange Online." -ForegroundColor Red
    exit 1
}
