$ExchangeConnectionTextBlock.Text = "Connecting to Exchange Online..."
$ExchangeConnectionTextBlock.Foreground = [System.Windows.Media.Brushes]::Gray
$authWindow.Dispatcher.Invoke([System.Windows.Threading.DispatcherPriority]::Background, [action]{})

$maxRetryDuration = 45 # seconds
$retryInterval = 15 # seconds
$retryAttempts = $maxRetryDuration / $retryInterval
$connected = $false
$attempt = 0
$timeoutPerAttempt = 10 # seconds per attempt to avoid hanging indefinitely

while (-not $connected -and $attempt -lt $retryAttempts) {
    $attempt++
    Write-Host "Attempt $attempt - Connecting to Exchange Online..." -ForegroundColor Yellow

    # Start connection attempt in a background job to monitor for timeouts
    $connectionJob = Start-Job -ScriptBlock {
        Connect-ExchangeOnline -ShowBanner:$false -ErrorAction Stop
    }

    # Wait for the job to complete with a timeout
    $jobCompleted = $connectionJob | Wait-Job -Timeout $timeoutPerAttempt

    # Check if job completed successfully within the timeout
    if ($jobCompleted) {
        try {
            # If successful, check the connection state
            $connectionInfo = Get-ConnectionInformation | Select-Object -Property State
            if ($connectionInfo.State -eq "Connected") {
                Write-Host "Connected to Exchange Online successfully!" -ForegroundColor Green
                $ExchangeConnectionTextBlock.Text = "Success!"
                $ExchangeConnectionTextBlock.Foreground = [System.Windows.Media.Brushes]::Green
                $authWindow.Dispatcher.Invoke([System.Windows.Threading.DispatcherPriority]::Background, [action]{})

                $SharedMailboxManagementButton.IsEnabled = $true
                $connected = $true
            } else {
                throw "Connection state is not 'Connected'. Retrying..."
            }
        } catch {
            Write-Host "Connection failed. Retrying in $retryInterval seconds..." -ForegroundColor Red

            # Countdown for retry
            for ($i = $retryInterval; $i -gt 0; $i--) {
                Write-Host "$i" -NoNewline

                $ExchangeConnectionTextBlock.Text = "Retrying in $i seconds"
                $ExchangeConnectionTextBlock.Foreground = [System.Windows.Media.Brushes]::Red
                $authWindow.Dispatcher.Invoke([System.Windows.Threading.DispatcherPriority]::Background, [action]{})

                Start-Sleep -Seconds 1
                Write-Host "`r" -NoNewline
            }
        }
    } else {
        # If the job is hanging, terminate it
        Write-Host "Connection attempt timed out. Retrying in $retryInterval seconds..." -ForegroundColor Red
        Stop-Job -Job $connectionJob | Out-Null
        
        # Countdown for retry
        for ($i = $retryInterval; $i -gt 0; $i--) {
            Write-Host "$i" -NoNewline

            $ExchangeConnectionTextBlock.Text = "Retrying in $i seconds"
            $ExchangeConnectionTextBlock.Foreground = [System.Windows.Media.Brushes]::Red
            $authWindow.Dispatcher.Invoke([System.Windows.Threading.DispatcherPriority]::Background, [action]{})

            Start-Sleep -Seconds 1
            Write-Host "`r" -NoNewline
        }
    }

    # Clean up the job
    Remove-Job -Job $connectionJob -Force
}

# Check if connection was ultimately unsuccessful
if (-not $connected) {
    Write-Host "Unable to connect to Exchange Online after $maxRetryDuration seconds." -ForegroundColor Red
    $ExchangeConnectionTextBlock.Text = "Failed Connection!"
    $ExchangeConnectionTextBlock.Foreground = [System.Windows.Media.Brushes]::Red
    $authWindow.Dispatcher.Invoke([System.Windows.Threading.DispatcherPriority]::Background, [action]{})
    exit 1
}