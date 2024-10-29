$ExchangeConnectionTextBlock.Text = "Connecting to Exchange Online..."
$ExchangeConnectionTextBlock.Foreground = [System.Windows.Media.Brushes]::Gray
$authWindow.Dispatcher.Invoke([System.Windows.Threading.DispatcherPriority]::Background, [action]{})

# Maximum duration to wait for connection (60 seconds)
$maxWaitDuration = 60
$retryInterval = 15  # Adjusted retry interval to 15 seconds
$elapsedTime = 0
$connected = $false

Write-Host "Attempting to connect to Exchange Online..." -ForegroundColor Yellow

# Start connection attempt in a background job
$connectionJob = Start-Job -ScriptBlock {
    Connect-ExchangeOnline -ShowBanner:$false -ErrorAction Stop
}

# Loop to track elapsed time and check job status
while (-not $connected -and $elapsedTime -lt $maxWaitDuration) {
    # Check if job completed successfully
    if ($connectionJob.State -eq 'Completed') {
        try {
            # Check the connection state
            $connectionInfo = Get-ConnectionInformation | Select-Object -Property State
            if ($connectionInfo.State -eq "Connected") {
                Write-Host "Connected to Exchange Online successfully!" -ForegroundColor Green
                $ExchangeConnectionTextBlock.Text = "Success!"
                $ExchangeConnectionTextBlock.Foreground = [System.Windows.Media.Brushes]::Green
                $authWindow.Dispatcher.Invoke([System.Windows.Threading.DispatcherPriority]::Background, [action]{})

                $SharedMailboxManagementButton.IsEnabled = $true
                $connected = $true
                break
            } else {
                throw "Connection state is not 'Connected'."
            }
        } catch {
            Write-Host "Connection failed within initial attempt." -ForegroundColor Red
        }
    }

    # Display appropriate messages based on elapsed time
    switch ($elapsedTime) {
        15 { 
            Write-Host "Please wait..." -ForegroundColor Yellow 
            $ExchangeConnectionTextBlock.Text = "Please wait..."
            $ExchangeConnectionTextBlock.Foreground = [System.Windows.Media.Brushes]::Gray
            $authWindow.Dispatcher.Invoke([System.Windows.Threading.DispatcherPriority]::Background, [action]{})
        }
        30 { 
            Write-Host "Retrying connection..." -ForegroundColor Yellow 
            $ExchangeConnectionTextBlock.Text = "Retrying connection..."
            $ExchangeConnectionTextBlock.Foreground = [System.Windows.Media.Brushes]::Red
            $authWindow.Dispatcher.Invoke([System.Windows.Threading.DispatcherPriority]::Background, [action]{})
        }
        45 { 
            Write-Host "Almost there..." -ForegroundColor Yellow 
            $ExchangeConnectionTextBlock.Text = "Almost there..."
            $ExchangeConnectionTextBlock.Foreground = [System.Windows.Media.Brushes]::Gray
            $authWindow.Dispatcher.Invoke([System.Windows.Threading.DispatcherPriority]::Background, [action]{})
        }
    }

    # Display a 15-second countdown
    for ($i = $retryInterval; $i -gt 0; $i--) {
        Write-Host "$i" -NoNewline
        Start-Sleep -Seconds 1
        Write-Host "`r" -NoNewline
    }

    # Increment elapsed time by countdown interval
    $elapsedTime += $retryInterval
}

# If still not connected after 60 seconds, terminate job and show failure
if (-not $connected) {
    Write-Host "Failed to connect!" -ForegroundColor Red
    $ExchangeConnectionTextBlock.Text = "Failed to connect!"
    $ExchangeConnectionTextBlock.Foreground = [System.Windows.Media.Brushes]::Red
    Stop-Job -Job $connectionJob | Out-Null
    Remove-Job -Job $connectionJob -Force
    exit 1
}
