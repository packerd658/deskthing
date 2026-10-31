# Sets up Ollama on another computer (Linux) over SSH, from Windows.
# Asks for that computer's address and username, then runs ollama-setup.sh there with sudo.
$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$script = Join-Path $here 'ollama-setup.sh'
if (-not (Test-Path $script)) { Write-Host "ollama-setup.sh is missing. Keep it in the same folder as this file."; exit 1 }

Write-Host "Set up Ollama on another computer for the Desk Thing"
Write-Host "-----------------------------------------------------"
$addr = (Read-Host "Address of the Ollama computer (for example 192.168.1.60)").Trim()
$user = (Read-Host "Your username on that computer").Trim()
if (-not $addr -or -not $user) { Write-Host "Both are needed. Nothing was changed."; exit 1 }

# Send the script as base64 so it survives the trip intact (Linux line endings)
$text = (Get-Content $script -Raw) -replace "`r`n", "`n"
$b64 = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($text))
$remote = "echo $b64 | base64 -d > /tmp/desk-ollama.sh && sudo bash /tmp/desk-ollama.sh; rm -f /tmp/desk-ollama.sh"

Write-Host ""
Write-Host "Connecting to $user@$addr ..."
Write-Host "Type that computer's password when asked: once to log in, once for sudo."
Write-Host "The password doesn't show while you type. If it seems to pause after logging in, that's the sudo password."
Write-Host ""
$log = Join-Path $here 'ollama-setup-log.txt'
ssh -tt -o StrictHostKeyChecking=accept-new "$user@$addr" $remote 2>&1 | Tee-Object -FilePath $log
Write-Host ""
Write-Host "Finished. The results are saved in $log"
Write-Host "In the Desk Thing: Settings -> Jarvis + Ollama -> address $addr"
