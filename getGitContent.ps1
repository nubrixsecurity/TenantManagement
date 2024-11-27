# CREATE DIRECTORY FOLDERS
$clonePath = Join-Path -Path $env:USERPROFILE -ChildPath "Documents\Management-Program"

if (Test-Path -Path $clonePath) {
    Remove-Item $clonePath -Recurse -Force
}

New-Item $clonePath -Type Directory
git clone https://github.com/nubrixsecurity/TenantManagement $clonePath

# UNBLOCK FILES
$files = Get-ChildItem $clonePath -Recurse -File

foreach ($file in $files) {
    Unblock-File -Path $file.FullName -Confirm:$false
}

# Create Shortcut
$scriptPath = Join-Path -Path $clonePath -ChildPath "main.ps1"
$shortcutPath = Join-Path -Path $env:USERPROFILE -ChildPath "Desktop\Management-Program.lnk"

# Check if the shortcut already exists
if (Test-Path $shortcutPath) {
    # If it exists, delete it
    Remove-Item $shortcutPath -Force
}

# Create a new shortcut
$wsh = New-Object -ComObject WScript.Shell
$shortcut = $wsh.CreateShortcut($shortcutPath)
$shortcut.TargetPath = "C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe"
$shortcut.Arguments = "-ExecutionPolicy Bypass -File `"$scriptPath`""
$shortcut.WorkingDirectory = $clonePath

# Set the custom icon location (replace with your actual icon path)
$iconPath = "$clonePath\icon.ico"
$shortcut.IconLocation = $iconPath

# Save the shortcut
$shortcut.Save()

# Clean up
$startTxtPath = Join-Path -Path $clonePath -ChildPath "start.txt"
$getGitContentPs1Path = Join-Path -Path $clonePath -ChildPath "getGitContent.ps1"

# Remove start.txt if it exists
if (Test-Path -Path $startTxtPath) {
    Remove-Item -Path $startTxtPath -Force
}

# Remove start.ps1 if it exists
if (Test-Path -Path $getGitContentPs1Path) {
    Remove-Item -Path $getGitContentPs1Path -Force
}