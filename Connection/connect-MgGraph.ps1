$GraphConnectionTextBlock.Text = "Connecting to Microsoft Graph..."
$GraphConnectionTextBlock.Foreground = [System.Windows.Media.Brushes]::Gray
$authWindow.Dispatcher.Invoke([System.Windows.Threading.DispatcherPriority]::Background, [action]{})

try {
    # Attempt to connect to Microsoft Graph
    Write-Host "Connecting to Microsoft Graph" -ForegroundColor Yellow
    $scopes = @("Group.ReadWrite.All", "User.ReadWrite.All", "Directory.ReadWrite.All")
    Connect-MgGraph -Scopes $scopes

    # Connection to Microsoft Graph was successful
    Write-Host "Connected to Microsoft Graph successfully!" -ForegroundColor Green

    $GraphConnectionTextBlock.Text = "Success!"
    $GraphConnectionTextBlock.Foreground = [System.Windows.Media.Brushes]::Green
    $authWindow.Dispatcher.Invoke([System.Windows.Threading.DispatcherPriority]::Background, [action]{})

    # Enable buttons for group management after successful connection
    $CreateUserButton.IsEnabled = $true
    $GroupMembershipButton.IsEnabled = $true
    $GroupManagementButton.IsEnabled = $true
    $ConnectToExchangeButton.IsEnabled = $true

} catch {
    # Handle failure in connecting to Microsoft Graph
    Write-Host "Failed to connect to Microsoft Graph." -ForegroundColor Red

    $GraphConnectionTextBlock.Text = "Failed Connection!"
    $GraphConnectionTextBlock.Foreground = [System.Windows.Media.Brushes]::Red

    exit 1
}