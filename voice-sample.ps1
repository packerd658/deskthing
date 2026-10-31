# Plays the TruckNav voice directions with the same Windows voice the Desk Thing uses,
# lists the voices Windows has, and saves a copy as voice-sample.wav next to this script.
$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$wantFile = Join-Path $here 'voice.txt'
$want = if (Test-Path $wantFile) { (Get-Content $wantFile -Raw).Trim() } else { '' }
function Get-VoiceRank([string]$n, [bool]$us) {
  if ($want -and $n -like "*$want*") { return 0 }
  if (-not $us) { return 99 }
  $r = 50
  if ($n -like '*Natural*') { $r = 10; if ($n -like '*Online*') { $r += 5 } }
  foreach ($fav in @('Ava','Jenny','Aria','Emma')) { if ($n -like "*$fav*") { $r -= 4; break } }
  if ($r -eq 50 -and $n -like '*Zira*') { $r = 40 }
  return $r
}
$sp = New-Object -ComObject SAPI.SpVoice
$best = $null; $bestRank = 999
Write-Host "Voices on this PC:"
foreach ($v in $sp.GetVoices()) {
  $n = $v.GetDescription(); Write-Host "  - $n"
  $lang = ''; try { $lang = $v.GetAttribute('Language') } catch {}
  $us = ($lang -split ';' | ForEach-Object { $_.Trim().ToLower() }) -contains '409' -or $n -like '*English (United States)*'
  $rank = Get-VoiceRank $n $us
  if ($rank -lt $bestRank) { $best = $v; $bestRank = $rank }
}
if ($best -and $bestRank -lt 99) { $sp.Voice = $best }
Write-Host ""
Write-Host "Using: $($sp.Voice.GetDescription())"
Write-Host "(To pick a different one, put part of its name, like Andrew, in voice.txt in this folder.)"
Write-Host ""
$lines = @('In 0.6 miles, turn left', 'Turn left', 'In 1.2 miles, keep right', 'Keep right', 'It''s 48 degrees and cloudy', 'You have arrived')
$wav = Join-Path $here 'voice-sample.wav'
$fs = New-Object -ComObject SAPI.SpFileStream
$fs.Open($wav, 3, $false)
$sp.AudioOutputStream = $fs
foreach ($l in $lines) { [void]$sp.Speak($l, 0) }
$fs.Close()
$sp.AudioOutputStream = $null
foreach ($l in $lines) { Write-Host "  $l"; [void]$sp.Speak($l, 0); Start-Sleep -Milliseconds 500 }
Write-Host ""
Write-Host "Saved a copy as $wav"
