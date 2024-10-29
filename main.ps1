& "$PSScriptRoot\Connection\Import-Modules.ps1"
& "$PSScriptRoot\Connection\Connect-Modules.ps1"

# Load the WPF assembly
Add-Type -AssemblyName PresentationFramework

# Function to load XAML from a file and return a window object
function Load-WindowFromXAML {
    param ($XamlPath)
    
    $XamlContent = Get-Content -Raw -Path $XamlPath
    $XamlReader = New-Object System.Xml.XmlTextReader ([System.IO.StringReader]::new($XamlContent))
    return [System.Windows.Markup.XamlReader]::Load($XamlReader)
}

# Define the paths to the XAML files
$authPath = "$PSScriptRoot\XAML\authentication.xaml"
$createUserPath = "$PSScriptRoot\XAML\createUser.xaml"
$groupMembershipPath = "$PSScriptRoot\XAML\groupMembership.xaml"
$groupManagementPath = "$PSScriptRoot\XAML\groupManagement.xaml"
$sharedmailboxManagementPath = "$PSScriptRoot\XAML\sharedmailboxManagement.xaml"

# Initialize 
$allUsers = @()
$allGroups = @()
$allSharedMailboxes = @()
$selectedUserId = $null
$selectedGroupId = $null
$selectedSharedMailboxId = $null
#$defaultGroups = @("License - M365 Business Premium", "MFA Users", "SSPR Users", "Intune Users", "LastPass Users", "TEAM")
$defaultGroups = @("Intune Users", "TEST SEC", "TEST M365")

# Load the main window
$authWindow = Load-WindowFromXAML -XamlPath $authPath

# Retrieve controls
$CreateUserButton = $authWindow.FindName("CreateUserButton")
$GroupMembershipButton = $authWindow.FindName("GroupMembershipButton")
$GroupManagementButton = $authWindow.FindName("GroupManagementButton")
$SharedMailboxManagementButton = $authWindow.FindName("SharedMailboxManagementButton")

# Initially disable the Create User button
$CreateUserButton.IsEnabled = $false
$GroupMembershipButton.IsEnabled = $false
$GroupManagementButton.IsEnabled = $false
$SharedMailboxManagementButton.IsEnabled = $false

# Check connection
$connectionInfo = Get-ConnectionInformation | Select-Object -Property State
if((Get-MgContext) -ne $null -and (Get-ConnectionInformation).state -eq "Connected"){
    $CreateUserButton.IsEnabled = $true
    $GroupMembershipButton.IsEnabled = $true
    $GroupManagementButton.IsEnabled = $true
    $SharedMailboxManagementButton.IsEnabled = $true
}

$CreateUserButton.Add_Click({
    # Load the Create User window from XAML
    $createUserWindow = Load-WindowFromXAML -XamlPath $createUserPath

    # Retrieve controls from the Create User window
    $FirstNameTextBox = $createUserWindow.FindName("FirstNameTextBox")
    $LastNameTextBox = $createUserWindow.FindName("LastNameTextBox")
    $EmailTextBox = $createUserWindow.FindName("EmailTextBox")
    $AliasTextBox = $createUserWindow.FindName("AliasTextBox")
    $TelephoneExtTextBox = $createUserWindow.FindName("TelephoneExtTextBox")
    $LocationComboBox = $createUserWindow.FindName("LocationComboBox")
    $CreateUserSubmitButton = $createUserWindow.FindName("CreateUserSubmitButton")
    $UserDetailsTextBox = $createUserWindow.FindName("UserDetailsTextBox")
    
    # Event handler for submitting the new user creation
    $CreateUserSubmitButton.Add_Click({
        $firstName = $FirstNameTextBox.Text
        $lastName = $LastNameTextBox.Text
        $alias = $AliasTextBox.Text
        $telephoneExt = $TelephoneExtTextBox.Text
        $location = $LocationComboBox.SelectedItem.Content
        $email = $EmailTextBox.Text

        if ([string]::IsNullOrWhiteSpace($firstName) -or [string]::IsNullOrWhiteSpace($lastName) -or 
            [string]::IsNullOrWhiteSpace($email) -or [string]::IsNullOrWhiteSpace($alias) -or 
            [string]::IsNullOrWhiteSpace($telephoneExt) -or [string]::IsNullOrWhiteSpace($location)) {
            [System.Windows.MessageBox]::Show("Please fill in all fields.", "Missing Information", 
                                            [System.Windows.MessageBoxButton]::OK, 
                                            [System.Windows.MessageBoxImage]::Warning)
            return
        }

        Function Get-RandomPassword {
            # Define parameters
            param([int]$PasswordLength = 12) # Set your desired password length (12 is a common minimum for security)

            # ASCII Character sets for Password
            $CharacterSet = @{
                Lowercase   = (97..122) | Get-Random -Count 3 | ForEach-Object {[char]$_}
                Uppercase   = (65..90)  | Get-Random -Count 3 | ForEach-Object {[char]$_}
                Numeric     = (48..57)  | Get-Random -Count 3 | ForEach-Object {[char]$_}
                SpecialChar = ('!' , '@') | Get-Random -Count 3 | ForEach-Object {[char]$_}
            }

            # Create Random Password by combining characters from each set
            $StringSet = `
                $CharacterSet.Uppercase + `
                $CharacterSet.Lowercase + `
                $CharacterSet.Numeric + `
                $CharacterSet.SpecialChar

            # Shuffle characters and join to create the final password
            $Password = -join (Get-Random -Count $PasswordLength -InputObject $StringSet)
            
            return $Password
        }

        # Generate a password
        $password = Get-RandomPassword
        $PasswordProfile = @{
            Password = $password
            ForceChangePasswordNextSignIn = $false
        }

        # Attempt to create the new user
        try {
            $newUser = New-MgUser `
                        -DisplayName "$firstName $lastName" `
                        -UserPrincipalName $email `
                        -MailNickname "$firstName.$lastName" `
                        -GivenName $firstName `
                        -Surname $lastName `
                        -AccountEnabled `
                        -PasswordProfile $PasswordProfile `
                        -BusinessPhones $telephoneExt `
                        -OfficeLocation $location `
                        -UsageLocation "US" `
                        -OtherMails $alias       
            
            # Show user details in the UserDetailsTextBox
            [System.Windows.MessageBox]::Show("User was created successfully!")
            $UserDetailsTextBox.Text = "$email`n$password"

            foreach ($groupName in $defaultGroups) {
                $group = Get-MgGroup -Filter "displayName eq '$groupName'" -ErrorAction SilentlyContinue
                if ($group) {
                    # Adding the user to the group
                    New-MgGroupMember -GroupId $group.Id -DirectoryObjectId $newUser.Id
                } else {
                    Write-Output "Group not found: $groupName"
                }
            }
                       
        }
        catch {
            [System.Windows.MessageBox]::Show("Failed to create user: $_")
        }

        #$createUserWindow.Close()
    })

    # Show the Create User window
    $createUserWindow.ShowDialog() | Out-Null
})

$GroupMembershipButton.Add_Click({
    # Load the Create User window from XAML
    $groupMembershipWindow = Load-WindowFromXAML -XamlPath $groupMembershipPath

    # Find controls in the second window
    $UserDisplayTextBox = $groupMembershipWindow.FindName("UserDisplayTextBox")
    $UserSelectionTextBox = $groupMembershipWindow.FindName("UserSelectionTextBox")
    $SelectUserButton = $groupMembershipWindow.FindName("SelectUserButton")
    $SelectedUserTextBlock = $groupMembershipWindow.FindName("SelectedUserTextBlock")
    $GroupsDisplayTextBox = $groupMembershipWindow.FindName("GroupsDisplayTextBox")
    $CloseButton = $groupMembershipWindow.FindName("CloseGroupMembershipWindowButton")

    # Event handler for the Close button
    $CloseButton.Add_Click({
        $groupMembershipWindow.Close()
    })

    try {
        $allUsers = Get-MgUser -All -ErrorAction Stop | Where-Object { $_.UserPrincipalName -notlike "*onmicrosoft.com" }
        if ($allUsers.Count -eq 0) {
            $UserDisplayTextBox.Text = "No users matched the filter."
            return
        }

        $userList = $allUsers | ForEach-Object { "[$([Array]::IndexOf($allUsers, $_) + 1)] $($_.DisplayName) ($($_.UserPrincipalName))" }
        $UserDisplayTextBox.Text = $userList -join "`r`n"

    } catch {
        $UserDisplayTextBox.Text = "Failed to retrieve users: $_"
    }

    # Event handler to select a user when the button is clicked
    $SelectUserButton.Add_Click({
        $selectedIndex = $UserSelectionTextBox.Text -as [int]
        $allUsers = Get-MgUser -All -ErrorAction Stop | Where-Object { $_.UserPrincipalName -notlike "*onmicrosoft.com" }

        if ($null -eq $allUsers -or $allUsers.Count -eq 0) {
            $SelectedUserTextBlock.Text = "No users available. Please retrieve users first."
            return
        } elseif ($null -eq $selectedIndex -or $selectedIndex -le 0 -or $selectedIndex -gt $allUsers.Count) {
            $SelectedUserTextBlock.Text = "Invalid selection. Please enter a number between 1 and $($allUsers.Count)."
            return
        } else {        
            $selectedUser = $allUsers[$selectedIndex - 1]
            $userPrincipalName = $selectedUser.UserPrincipalName
            $user = Get-MgUser -Filter "UserPrincipalName eq '$userPrincipalName'" | select-object id -ErrorAction Stop
            $selectedUserId = $user.id
            $SelectedUserTextBlock.Text = "Selected User: $($selectedUser.DisplayName)"

            # Get groups the user is a member of
            try {                
                $userGroups = Get-MgUserMemberOf -UserId $selectedUser.Id -ErrorAction Stop
                $groupList = @()
                
                $getsessions = Get-ConnectionInformation | Select-Object -Property State
                if (!$getsessions.state) {
                    if ($userGroups.Count -eq 0) {
                        $GroupsDisplayTextBox.Text = "The selected user is not a member of any groups."
                    } else {
                        foreach ($group in $userGroups) {
                            $groupDetails = Get-MgGroup -GroupId $group.Id -ErrorAction SilentlyContinue
                            if ($groupDetails.GroupTypes -contains "Unified") {
                                $groupList += "$($groupDetails.DisplayName) (M365 Group)"
                            } elseif ($groupDetails.GroupTypes -notcontains "Unified" -and $groupDetails.DisplayName -ne $null) {
                                $groupList += "$($groupDetails.DisplayName) (Security Group)"
                            }
                        }
                    }
                } else {
                    if ($userGroups.Count -eq 0) {
                        $GroupsDisplayTextBox.Text = "The selected user is not a member of any groups."
                    } else {
                        $sharedMailboxes = (Get-Mailbox -Filter {RecipientTypeDetails -eq "SharedMailbox"} | Get-MailboxPermission | Where-Object { $_.User -eq $userPrincipalName }).identity

                        foreach ($group in $userGroups) {
                            $groupDetails = Get-MgGroup -GroupId $group.Id -ErrorAction SilentlyContinue
                            if ($groupDetails.GroupTypes -contains "Unified") {
                                $groupList += "$($groupDetails.DisplayName) (M365 Group)"
                            } elseif ($groupDetails.GroupTypes -notcontains "Unified" -and $groupDetails.DisplayName -ne $null) {
                                $groupList += "$($groupDetails.DisplayName) (Security Group)"
                            }
                        }

                        # Add shared mailboxes to the list
                        if ($sharedMailboxes.Count -gt 0) {
                            foreach ($i in $sharedMailboxes) {
                                $mailbox = $i -replace '\d+$', ''
                                $groupList += "$mailbox (Shared Mailbox)"
                            }
                        }
                    }
                     
                }

                # Sort the group list alphabetically
                $sortedGroupList = $groupList | Sort-Object

                # Initialize an empty array for the final output with numbering
                $numberedGroupList = @()

                # Add numbering to the sorted group names
                foreach ($group in $sortedGroupList) {
                    $numberedGroupList += "$group"
                }

                $GroupsDisplayTextBox.Text = $numberedGroupList -join "`r`n"

            } catch {
                $GroupsDisplayTextBox.Text = "Failed to retrieve groups: $_"
            }           
            
        }
        
    })

    $groupMembershipWindow.ShowDialog() | Out-Null
})  

$GroupManagementButton.Add_Click({
    # Load the Create User window from XAML
    $groupManagementWindow = Load-WindowFromXAML -XamlPath $groupManagementPath

    # Find controls in the second window
    $UserDisplayTextBox = $groupManagementWindow.FindName("UserDisplayTextBox")
    $UserSelectionTextBox = $groupManagementWindow.FindName("UserSelectionTextBox")
    $SelectUserButton = $groupManagementWindow.FindName("SelectUserButton")
    $SelectedUserTextBlock = $groupManagementWindow.FindName("SelectedUserTextBlock")
    
    $AllGroupsDisplayTextBox = $groupManagementWindow.FindName("AllGroupsDisplayTextBox")
    $GroupSelectionTextBox = $groupManagementWindow.FindName("GroupSelectionTextBox")
    $SelectGroupButton = $groupManagementWindow.FindName("SelectGroupButton")
    $SelectedGroupTextBlock = $groupManagementWindow.FindName("SelectedGroupTextBlock")

    $ConfirmUserIdSelectionTextBox = $groupManagementWindow.FindName("ConfirmUserIdSelectionTextBox")
    $ConfirmGroupIdSelectionTextBox = $groupManagementWindow.FindName("ConfirmGroupIdSelectionTextBox")
    $ConfirmAddButton = $groupManagementWindow.FindName("ConfirmAddButton")
    $ConfirmRemoveButton = $groupManagementWindow.FindName("ConfirmRemoveButton")

    try {
        $allUsers = Get-MgUser -All -ErrorAction Stop | Where-Object { $_.UserPrincipalName -notlike "*onmicrosoft.com" }
        if ($allUsers.Count -eq 0) {
            $UserDisplayTextBox.Text = "No users matched the filter."
            return
        }

        $userList = $allUsers | ForEach-Object { "[$([Array]::IndexOf($allUsers, $_) + 1)] $($_.DisplayName) ($($_.UserPrincipalName))" }
        $UserDisplayTextBox.Text = $userList -join "`r`n"

    } catch {
        $UserDisplayTextBox.Text = "Failed to retrieve users: $_"
    }

    # Event handler to select a user when the button is clicked
    $SelectUserButton.Add_Click({
        $selectedIndex = $UserSelectionTextBox.Text -as [int]
        $allUsers = Get-MgUser -All -ErrorAction Stop | Where-Object { $_.UserPrincipalName -notlike "*onmicrosoft.com" }

        if ($null -eq $selectedIndex -or $selectedIndex -le 0 -or $selectedIndex -gt $allUsers.Count) {
            $SelectedUserTextBlock.Text = "Invalid selection. Please enter a number between 1 and $($allUsers.Count)."
            return
        } else {        
            $selectedUser = $allUsers[$selectedIndex - 1]
            $userPrincipalName = $selectedUser.UserPrincipalName
            $user = Get-MgUser -Filter "UserPrincipalName eq '$userPrincipalName'" | select-object id -ErrorAction Stop
            $selectedUserId = $user.id
            $SelectedUserTextBlock.Text = "Selected: $($selectedUser.DisplayName)"           
        }

        # Get all groups from Microsoft Graph
        $allGroups = Get-MgGroup -All
        $sharedMailboxes = Get-Mailbox -ResultSize Unlimited -RecipientTypeDetails SharedMailbox

        # Initialize an array to hold group details
        $groupsList = @()

        # Populate the groups list with group names
        foreach ($group in $allGroups) {
            if ($group.GroupTypes -contains "Unified") {
                $groupsList += [PSCustomObject]@{
                    DisplayName = $group.DisplayName
                    Type = "M365 Group"
                }
            } else {
                $groupsList += [PSCustomObject]@{
                    DisplayName = $group.DisplayName
                    Type = "Security Group"
                }
            }
        }

        # Sort the group list alphabetically
        $sortedGroupsList = $groupsList | Sort-Object DisplayName

        # Initialize an empty array for the final output with numbering
        $numberedGroupsList = @()

        # Add numbering to the sorted group names
        $count = 1
        foreach ($group in $sortedGroupsList) {
            $numberedGroupsList += "[$count] $($group.DisplayName) ($($group.Type))"
            $count++
        }

        # Display the numbered and sorted groups in the text box
        $AllGroupsDisplayTextBox.Text = $numberedGroupsList -join "`r`n"

        # Function to copy user and group info to clipboard
        function CopyToClipboard {
            if ($null -eq $selectedUserId) {
                return
            }

            $clipboardText = $selectedUserId

            # Copy the concatenated string to the clipboard
            [System.Windows.Clipboard]::SetText($clipboardText)
        }

        CopyToClipboard

        # Function to paste clipboard content into a specific TextBox with appending
         function PasteClipboardToTextBox {
            param ($textBox)
            if ([System.Windows.Clipboard]::ContainsText()) {
                $clipboardText = [System.Windows.Clipboard]::GetText()
                
                $textBox.Text = $clipboardText
            }
        }

        # Call function to append clipboard content to the TextBox
        PasteClipboardToTextBox -textBox $ConfirmUserIdSelectionTextBox


        # Event handler for selecting a group
        $SelectGroupButton.Add_Click({
            $selectedIndex = $GroupSelectionTextBox.Text -as [int]
            
            # Get all groups from Microsoft Graph
            $allGroups = Get-MgGroup -All

            # Initialize an array to hold group details
            $groupsList = @()

            # Populate the groups list with group names
            foreach ($group in $allGroups) {
                if ($group.GroupTypes -contains "Unified") {
                    $groupsList += [PSCustomObject]@{
                        DisplayName = $group.DisplayName
                        Type = "M365 Group"
                    }
                } else {
                    $groupsList += [PSCustomObject]@{
                        DisplayName = $group.DisplayName
                        Type = "Security Group"
                    }
                }
            }

            # Sort the group list alphabetically
            $sortedGroupsList = $groupsList | Sort-Object DisplayName

            if ($null -eq $selectedIndex -or $selectedIndex -le 0 -or $selectedIndex -gt $sortedGroupsList.Count) {
                $SelectedGroupTextBlock.Text = "Invalid selection. Please enter a number between 1 and $($sortedGroupsList.Count)."
                return
            } else {
                # Get the actual group from the sorted list based on the selected index
                $selectedGroup = $sortedGroupsList[$selectedIndex - 1]
                $groupName = $selectedGroup.DisplayName
                $group = Get-MgGroup -Filter "displayName eq '$groupName'" | select-object id -ErrorAction Stop
                $selectedGroupId = $group.id
                $SelectedGroupTextBlock.Text = "Selected: $($selectedGroup.DisplayName) ($($selectedGroup.Type))"
            }

            # Function to copy user and group info to clipboard
            function CopyToClipboard {
                if ($null -eq $selectedGroupId) {
                    return
                }

                # Create a concatenated string with both user and group information
                $clipboardText = $selectedGroupId

                # Copy the concatenated string to the clipboard
                [System.Windows.Clipboard]::SetText($clipboardText)
            }

            CopyToClipboard

            # Function to paste clipboard content into a specific TextBox with appending
            function PasteClipboardToTextBox {
                param ($textBox)
                if ([System.Windows.Clipboard]::ContainsText()) {
                    $clipboardText = [System.Windows.Clipboard]::GetText()
                    
                    $textBox.Text = $clipboardText
                }
            }

            # Call function to append clipboard content to the TextBox
            PasteClipboardToTextBox -textBox $ConfirmGroupIdSelectionTextBox

            # Confirm button click event
            $ConfirmAddButton.Add_Click({
                $selectUserId = $ConfirmUserIdSelectionTextBox.Text
                $selectGroupId = $ConfirmGroupIdSelectionTextBox.Text

                # Validation step
                if ([string]::IsNullOrWhiteSpace($selectUserId) -or [string]::IsNullOrWhiteSpace($selectGroupId)) {
                    [System.Windows.MessageBox]::Show("Please fill out both the User ID and Group ID fields before confirming.", "Validation Error", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Warning)
                    return
                }

                # Try to add the user to the group
                try {
                    New-MgGroupMember -GroupId $selectGroupId -DirectoryObjectId $selectUserId -ErrorAction Stop
                    [System.Windows.MessageBox]::Show("User added to group successfully.")
                } catch {
                    [System.Windows.MessageBox]::Show("Failed to add user to group: $_")
                }

                $groupManagementWindow.Close()
            })

            # Confirm button click event
            $ConfirmRemoveButton.Add_Click({
                $selectUserId = $ConfirmUserIdSelectionTextBox.Text
                $selectGroupId = $ConfirmGroupIdSelectionTextBox.Text

                # Validation step
                if ([string]::IsNullOrWhiteSpace($selectUserId) -or [string]::IsNullOrWhiteSpace($selectGroupId)) {
                    [System.Windows.MessageBox]::Show("Please fill out both the User ID and Group ID fields before confirming.", "Validation Error", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Warning)
                    return
                }

                # Try to remove the user from the group
                try {
                    Remove-MgGroupMemberDirectoryObjectByRef -GroupId $selectGroupId -DirectoryObjectId $selectUserId -ErrorAction Stop
                    [System.Windows.MessageBox]::Show("User removed from group successfully.")
                } catch {
                    [System.Windows.MessageBox]::Show("Failed to remove user from group: $_")
                }

                $groupManagementWindow.Close() 
            })

        })

    })

    $groupManagementWindow.ShowDialog() | Out-Null
})  

$SharedMailboxManagementButton.Add_Click({
    # Load the Create User window from XAML
    $sharedmailboxManagementWindow = Load-WindowFromXAML -XamlPath $sharedmailboxManagementPath

    # Find controls in the second window
    $UserDisplayTextBox = $sharedmailboxManagementWindow.FindName("UserDisplayTextBox")
    $UserSelectionTextBox = $sharedmailboxManagementWindow.FindName("UserSelectionTextBox")
    $SelectUserButton = $sharedmailboxManagementWindow.FindName("SelectUserButton")
    $SelectedUserTextBlock = $sharedmailboxManagementWindow.FindName("SelectedUserTextBlock")
    
    $AllSharedMailboxesDisplayTextBox = $sharedmailboxManagementWindow.FindName("AllSharedMailboxesDisplayTextBox")
    $SharedMailboxSelectionTextBox = $sharedmailboxManagementWindow.FindName("SharedMailboxSelectionTextBox")
    $SelectSharedMailboxButton = $sharedmailboxManagementWindow.FindName("SelectSharedMailboxButton")
    $SelectedSharedMailboxTextBlock = $sharedmailboxManagementWindow.FindName("SelectedSharedMailboxTextBlock")

    $ConfirmUserIdSelectionTextBox = $sharedmailboxManagementWindow.FindName("ConfirmUserIdSelectionTextBox")
    $ConfirmSharedMailboxIdSelectionTextBox = $sharedmailboxManagementWindow.FindName("ConfirmSharedMailboxIdSelectionTextBox")
    $ConfirmAddButton = $sharedmailboxManagementWindow.FindName("ConfirmAddButton")
    $ConfirmRemoveButton = $sharedmailboxManagementWindow.FindName("ConfirmRemoveButton")

    try {
        $allUsers = Get-MgUser -All -ErrorAction Stop | Where-Object { $_.UserPrincipalName -notlike "*onmicrosoft.com" }
        if ($allUsers.Count -eq 0) {
            $UserDisplayTextBox.Text = "No users matched the filter."
            return
        }

        $userList = $allUsers | ForEach-Object { "[$([Array]::IndexOf($allUsers, $_) + 1)] $($_.DisplayName) ($($_.UserPrincipalName))" }
        $UserDisplayTextBox.Text = $userList -join "`r`n"

    } catch {
        $UserDisplayTextBox.Text = "Failed to retrieve users: $_"
    }

    # Event handler to select a user when the button is clicked
    $SelectUserButton.Add_Click({
        $selectedIndex = $UserSelectionTextBox.Text -as [int]
        $allUsers = Get-MgUser -All -ErrorAction Stop | Where-Object { $_.UserPrincipalName -notlike "*onmicrosoft.com" }

        if ($null -eq $selectedIndex -or $selectedIndex -le 0 -or $selectedIndex -gt $allUsers.Count) {
            $SelectedUserTextBlock.Text = "Invalid selection. Please enter a number between 1 and $($allUsers.Count)."
            return
        } else {        
            $selectedUser = $allUsers[$selectedIndex - 1]
            $userPrincipalName = $selectedUser.UserPrincipalName
            $user = Get-MgUser -Filter "UserPrincipalName eq '$userPrincipalName'" | select-object id -ErrorAction Stop
            $selectedUserId = $user.id
            $SelectedUserTextBlock.Text = "Selected: $($selectedUser.DisplayName)"           
        }

        $allSharedMailboxes = Get-Mailbox -ResultSize Unlimited -RecipientTypeDetails SharedMailbox

        # Initialize an array to hold group details
        $sharedMailboxList = @()

        # Populate the groups list with group names
        foreach ($sharedMailbox in $allSharedMailboxes) {
            $sharedMailboxList += [PSCustomObject]@{
                DisplayName = $sharedMailbox.DisplayName
                Type = "Shared Mailbox"
                Email = $sharedMailbox.PrimarySmtpAddress
            }  
        }        
        
        # Sort the group list alphabetically
        $sortedSharedMailboxList = $sharedMailboxList | Sort-Object DisplayName

        # Initialize an empty array for the final output with numbering
        $numberedSharedMailboxList = @()

        # Add numbering to the sorted group names
        $count = 1
        foreach ($sharedMailbox in $sortedSharedMailboxList) {
            $numberedSharedMailboxList += "[$count] $($sharedMailbox.DisplayName) ($($sharedMailbox.Email))"
            $count++
        }

        # Display the numbered and sorted groups in the text box
        $AllSharedMailboxesDisplayTextBox.Text = $numberedSharedMailboxList -join "`r`n"

        # Function to copy user and group info to clipboard
        function CopyToClipboard {
            if ($null -eq $selectedUserId) {
                return
            }

            # Create a concatenated string with both user and group information
            $clipboardText = $selectedUserId

            # Copy the concatenated string to the clipboard
            [System.Windows.Clipboard]::SetText($clipboardText)
        }

        CopyToClipboard

        # Function to paste clipboard content into a specific TextBox with appending
        function PasteClipboardToTextBox {
            param ($textBox)
            if ([System.Windows.Clipboard]::ContainsText()) {
                $clipboardText = [System.Windows.Clipboard]::GetText()
                
                # Append clipboard content to existing text in the TextBox
                $textBox.Text = $clipboardText
            }
        }

        # Call function to append clipboard content to the TextBox
        PasteClipboardToTextBox -textBox $ConfirmUserIdSelectionTextBox


        # Event handler for selecting a group
        $SelectSharedMailboxButton.Add_Click({
            $selectedIndex = $SharedMailboxSelectionTextBox.Text -as [int]
            $allSharedMailboxes = @()
            
            $allSharedMailboxes = Get-Mailbox -ResultSize Unlimited -RecipientTypeDetails SharedMailbox

            # Initialize an array to hold group details
            $sharedMailboxList = @()

            # Populate the groups list with group names
            foreach ($sharedMailbox in $allSharedMailboxes) {
                $sharedMailboxList += [PSCustomObject]@{
                    DisplayName = $sharedMailbox.DisplayName
                }  
            }    

            # Sort the group list alphabetically
            $sortedSharedMailboxList = $sharedMailboxList | Sort-Object DisplayName       

            if ($null -eq $selectedIndex -or $selectedIndex -le 0 -or $selectedIndex -gt $sortedSharedMailboxList.Count) {
                $SelectedSharedMailboxTextBlock.Text = "Invalid selection. Please enter a number between 1 and $($sortedSharedMailboxList.Count)."
                return
            } else {
                # Get the actual group from the sorted list based on the selected index
                $selectedSharedMailbox = $sortedSharedMailboxList[$selectedIndex - 1]
                $sharedMailboxName = $selectedSharedMailbox.DisplayName                    
                $sharedMailboxNameId = (Get-Mailbox -ResultSize Unlimited -RecipientTypeDetails SharedMailbox | Where-object {$_.DisplayName -eq $sharedMailboxName}).guid
                $selectedSharedMailboxId = $sharedMailboxNameId.guid
                $SelectedSharedMailboxTextBlock.Text = "Selected: $sharedMailboxName" 
            }

            # Function to copy user and group info to clipboard
            function CopyToClipboard {
                if ($null -eq $selectedSharedMailboxId) {
                    return
                }

                # Create a concatenated string with both user and group information
                $clipboardText = $selectedSharedMailboxId

                # Copy the concatenated string to the clipboard
                [System.Windows.Clipboard]::SetText($clipboardText)
            }

            CopyToClipboard

            # Function to paste clipboard content into a specific TextBox with appending
            function PasteClipboardToTextBox {
                param ($textBox)
                if ([System.Windows.Clipboard]::ContainsText()) {
                    $clipboardText = [System.Windows.Clipboard]::GetText()
                    
                    # Append clipboard content to existing text in the TextBox
                    $textBox.Text = $clipboardText
                }
            }

            # Call function to append clipboard content to the TextBox
            PasteClipboardToTextBox -textBox $ConfirmSharedMailboxIdSelectionTextBox

            # Confirm button click event
            $ConfirmAddButton.Add_Click({
                $selectUserId = $ConfirmUserIdSelectionTextBox.Text
                $selectedSharedMailboxId = $ConfirmSharedMailboxIdSelectionTextBox.Text

                # Validation step
                if ([string]::IsNullOrWhiteSpace($selectUserId) -or [string]::IsNullOrWhiteSpace($selectedSharedMailboxId)) {
                    [System.Windows.MessageBox]::Show("Please fill out both the User ID and Mailbox ID fields before confirming.", "Validation Error", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Warning)
                    return
                }

                # Try to add the user to the group
                try {
                    Add-MailboxPermission -Identity $selectedSharedMailboxId -User $selectUserId -AccessRights FullAccess -InheritanceType All
                    Add-RecipientPermission -Identity $selectedSharedMailboxId -Trustee $selectUserId -AccessRights SendAs -Confirm:$false
                    [System.Windows.MessageBox]::Show("User added to mailbox successfully.")
                } catch {
                    [System.Windows.MessageBox]::Show("Failed to add user to mailbox: $_")
                }

                $sharedmailboxManagementWindow.Close()
            })

            # Confirm button click event
            $ConfirmRemoveButton.Add_Click({
                $selectUserId = $ConfirmUserIdSelectionTextBox.Text
                $selectedSharedMailboxId = $ConfirmSharedMailboxIdSelectionTextBox.Text

                # Validation step
                if ([string]::IsNullOrWhiteSpace($selectUserId) -or [string]::IsNullOrWhiteSpace($selectedSharedMailboxId)) {
                    [System.Windows.MessageBox]::Show("Please fill out both the User ID and Group ID fields before confirming.", "Validation Error", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Warning)
                    return
                }

                # Try to remove the user from the group
                try {
                    Remove-MailboxPermission -Identity $selectedSharedMailboxId -User $selectUserId -AccessRights FullAccess -InheritanceType All -Confirm:$false
                    Remove-RecipientPermission -Identity $selectedSharedMailboxId -Trustee $selectUserId -AccessRights SendAs -Confirm:$false
                    [System.Windows.MessageBox]::Show("User removed from group successfully.")
                } catch {
                    [System.Windows.MessageBox]::Show("Failed to remove user from group: $_")
                }

                $sharedmailboxManagementWindow.Close() 
            })

        })

    })

    $sharedmailboxManagementWindow.ShowDialog() | Out-Null
}) 


$authWindow.Add_Closing({
    Disconnect-ExchangeOnline -Confirm:$false
    Disconnect-MgGraph
})

$authWindow.ShowDialog() | Out-Null
