# Desk Thing audio helper
#  - http://<this PC>:26540/output       -> name, type and volume of Windows' current playback device
#  - http://<this PC>:26540/speak?text=… -> that text spoken by the Windows voice, as a WAV file
#    (used for TruckNav voice directions on the Pixel)
#  - http://<this PC>:26540/listen        -> listens once on this PC's microphone and returns what
#    was said (for the Desk Thing assistant). Nothing is recorded or saved.
#  - http://<this PC>:26540/wake          -> counts "Hey Jarvis" wake words (the Pixel checks it);
#    /wake?on=0 or ?on=1 turns the wake word off or on
#  - http://<this PC>:26540/mic?mute=1  -> mutes the microphone (stops listening completely); ?mute=0 turns it back on
# It never changes any audio settings.
param([switch]$Once)

$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$log = Join-Path $here 'audio-output.log'
function Log($m) { "$(Get-Date -Format s) $m" | Add-Content -Path $log }

Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;

namespace DeskThingAudio {
  [StructLayout(LayoutKind.Sequential)]
  public struct PROPERTYKEY { public Guid fmtid; public int pid; }

  [StructLayout(LayoutKind.Sequential)]
  public struct PROPVARIANT {
    public ushort vt; public ushort r1; public ushort r2; public ushort r3;
    public IntPtr p; public IntPtr p2;
  }

  [ComImport, Guid("886d8eeb-8cf2-4446-8d02-cdba1dbdcf99"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
  public interface IPropertyStore {
    [PreserveSig] int GetCount(out int count);
    [PreserveSig] int GetAt(int index, out PROPERTYKEY key);
    [PreserveSig] int GetValue(ref PROPERTYKEY key, out PROPVARIANT value);
  }

  [ComImport, Guid("D666063F-1587-4E43-81F1-B948E807363F"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
  public interface IMMDevice {
    [PreserveSig] int Activate(ref Guid iid, int clsCtx, IntPtr activationParams, [MarshalAs(UnmanagedType.IUnknown)] out object iface);
    [PreserveSig] int OpenPropertyStore(int access, out IPropertyStore store);
    [PreserveSig] int GetId([MarshalAs(UnmanagedType.LPWStr)] out string id);
    [PreserveSig] int GetState(out int state);
  }

  [ComImport, Guid("A95664D2-9614-4F35-A746-DE8DB63617E6"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
  public interface IMMDeviceEnumerator {
    [PreserveSig] int EnumAudioEndpoints(int dataFlow, int stateMask, out IntPtr devices);
    [PreserveSig] int GetDefaultAudioEndpoint(int dataFlow, int role, out IMMDevice device);
  }

  [ComImport, Guid("5CDF2C82-841E-4546-9722-0CF74078229A"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
  public interface IAudioEndpointVolume {
    [PreserveSig] int RegisterControlChangeNotify(IntPtr notify);
    [PreserveSig] int UnregisterControlChangeNotify(IntPtr notify);
    [PreserveSig] int GetChannelCount(out int count);
    [PreserveSig] int SetMasterVolumeLevel(float level, ref Guid ctx);
    [PreserveSig] int SetMasterVolumeLevelScalar(float level, ref Guid ctx);
    [PreserveSig] int GetMasterVolumeLevel(out float level);
    [PreserveSig] int GetMasterVolumeLevelScalar(out float level);
    [PreserveSig] int SetChannelVolumeLevel(int ch, float level, ref Guid ctx);
    [PreserveSig] int SetChannelVolumeLevelScalar(int ch, float level, ref Guid ctx);
    [PreserveSig] int GetChannelVolumeLevel(int ch, out float level);
    [PreserveSig] int GetChannelVolumeLevelScalar(int ch, out float level);
    [PreserveSig] int SetMute([MarshalAs(UnmanagedType.Bool)] bool mute, ref Guid ctx);
    [PreserveSig] int GetMute([MarshalAs(UnmanagedType.Bool)] out bool mute);
  }

  [ComImport, Guid("BCDE0395-E52F-467C-8E3D-C4579291692E")]
  public class MMDeviceEnumeratorCom { }

  public class Output {
    public string Name = "";
    public string Kind = "unknown";
    public int Volume = -1;
    public bool Muted = false;
    public string Error = "";

    static readonly string[] Kinds = { "network", "speakers", "line", "headphones", "microphone", "headset", "handset", "digital", "spdif", "hdmi", "unknown" };

    public static Output Get() {
      var o = new Output();
      try {
        var en = (IMMDeviceEnumerator)(new MMDeviceEnumeratorCom());
        IMMDevice dev;
        int hr = en.GetDefaultAudioEndpoint(0 /* render */, 1 /* multimedia */, out dev);
        if (hr != 0 || dev == null) { o.Error = "no default output (hr " + hr + ")"; return o; }

        IPropertyStore ps;
        if (dev.OpenPropertyStore(0, out ps) == 0 && ps != null) {
          var nameKey = new PROPERTYKEY { fmtid = new Guid("a45c254e-df1c-4efd-8020-67d146a850e0"), pid = 14 };
          PROPVARIANT v;
          if (ps.GetValue(ref nameKey, out v) == 0 && v.vt == 31) o.Name = Marshal.PtrToStringUni(v.p);
          var ffKey = new PROPERTYKEY { fmtid = new Guid("1da5d803-d492-4edd-8c23-e0c0ffee7f0e"), pid = 0 };
          PROPVARIANT f;
          if (ps.GetValue(ref ffKey, out f) == 0 && f.vt == 19) {
            int ff = (int)(f.p.ToInt64() & 0xFFFFFFFF);
            o.Kind = (ff >= 0 && ff < Kinds.Length) ? Kinds[ff] : "unknown";
          }
        }

        var iid = new Guid("5CDF2C82-841E-4546-9722-0CF74078229A");
        object vol;
        if (dev.Activate(ref iid, 23 /* CLSCTX_ALL */, IntPtr.Zero, out vol) == 0 && vol != null) {
          var ev = (IAudioEndpointVolume)vol;
          float s; if (ev.GetMasterVolumeLevelScalar(out s) == 0) o.Volume = (int)Math.Round(s * 100);
          bool m; if (ev.GetMute(out m) == 0) o.Muted = m;
        }
      } catch (Exception e) { o.Error = e.Message; }
      return o;
    }
  }
}
'@

function Get-OutputJson {
  $o = [DeskThingAudio.Output]::Get()
  if ($o.Error) { Log "read error: $($o.Error)" }
  return (@{ name = $o.Name; kind = $o.Kind; volume = $o.Volume; muted = $o.Muted; error = $o.Error } | ConvertTo-Json -Compress)
}

if ($Once) {
  $j = Get-OutputJson
  $j | Out-File -FilePath (Join-Path $here 'audio-output-test.txt') -Encoding utf8
  Write-Host $j
  exit
}

# Pick the voice: a name in voice.txt (next to this script) wins; otherwise the best US English
# "Natural" voice (from NaturalVoiceSAPIAdapter), otherwise Zira, otherwise the default.
# Natural voices only show up through Windows' SAPI COM interface, so that's tried first.
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

$script:sapi = $null
try {
  $sp = New-Object -ComObject SAPI.SpVoice
  $best = $null; $bestRank = 999; $names = @()
  foreach ($v in $sp.GetVoices()) {
    $n = $v.GetDescription(); $names += $n
    $lang = ''; try { $lang = $v.GetAttribute('Language') } catch {}
    $us = ($lang -split ';' | ForEach-Object { $_.Trim().ToLower() }) -contains '409' -or $n -like '*English (United States)*'
    $rank = Get-VoiceRank $n $us
    if ($rank -lt $bestRank) { $best = $v; $bestRank = $rank }
  }
  Log ("voices: " + ($names -join ' | '))
  if ($best -and $bestRank -lt 99) { $sp.Voice = $best }
  $sp.Rate = 0; $sp.Volume = 100
  $script:sapi = $sp
  Log "using voice: $($sp.Voice.GetDescription())"
} catch { Log "SAPI voice unavailable, using .NET voice: $($_.Exception.Message)" }

Add-Type -AssemblyName System.Speech
$synth = New-Object System.Speech.Synthesis.SpeechSynthesizer
if (-not $script:sapi) {
  $pick = $synth.GetInstalledVoices() | Where-Object { $_.Enabled } | Sort-Object { Get-VoiceRank $_.VoiceInfo.Name ($_.VoiceInfo.Culture.Name -eq 'en-US') } | Select-Object -First 1
  if ($pick) { $synth.SelectVoice($pick.VoiceInfo.Name) }
  $synth.Rate = 0; $synth.Volume = 100
  Log "using voice: $($synth.Voice.Name)"
}

function Get-SpeechWav([string]$text) {
  if ($script:sapi) {
    try {
      $fmt = New-Object -ComObject SAPI.SpAudioFormat
      $fmt.Type = 22   # 22 kHz, 16-bit, mono
      $mem = New-Object -ComObject SAPI.SpMemoryStream
      $mem.Format = $fmt
      $script:sapi.AudioOutputStream = $mem
      [void]$script:sapi.Speak($text, 0)
      $pcm = [byte[]]$mem.GetData()
      $script:sapi.AudioOutputStream = $null
      $ms = New-Object System.IO.MemoryStream; $bw = New-Object System.IO.BinaryWriter($ms)
      $bw.Write([Text.Encoding]::ASCII.GetBytes('RIFF')); $bw.Write([int](36 + $pcm.Length)); $bw.Write([Text.Encoding]::ASCII.GetBytes('WAVEfmt '))
      $bw.Write([int]16); $bw.Write([int16]1); $bw.Write([int16]1); $bw.Write([int]22050); $bw.Write([int]44100); $bw.Write([int16]2); $bw.Write([int16]16)
      $bw.Write([Text.Encoding]::ASCII.GetBytes('data')); $bw.Write([int]$pcm.Length); $bw.Write($pcm)
      return ,$ms.ToArray()
    } catch { Log "SAPI speak error: $($_.Exception.Message)" }
  }
  $ms = New-Object System.IO.MemoryStream
  $synth.SetOutputToWaveStream($ms)
  $synth.Speak($text)
  $synth.SetOutputToNull()
  return ,$ms.ToArray()   # the comma keeps PowerShell from unrolling the byte array
}

function Get-QueryValue([string]$target, [string]$name) {
  $q = ($target -split '\?', 2)[1]
  if (-not $q) { return '' }
  foreach ($pair in $q -split '&') {
    $kv = $pair -split '=', 2
    if ($kv[0] -eq $name -and $kv.Count -eq 2) { return [System.Uri]::UnescapeDataString($kv[1].Replace('+', ' ')) }
  }
  return ''
}

# ---------- assistant: speech recognition on this PC's microphone ----------
Add-Type -AssemblyName System.Speech
$script:rec = $null
$script:recError = ''

function Get-AtsCityPhrases {
  $phrases = New-Object System.Collections.Generic.HashSet[string]
  $file = Join-Path $env:APPDATA 'TruckNav\maps\ats\map-data\cities.json'
  if (-not (Test-Path $file)) { return @() }
  try {
    $cities = Get-Content $file -Raw | ConvertFrom-Json
    foreach ($c in $cities) {
      if (-not $c.name) { continue }
      $name = ($c.name -replace '[^A-Za-z .''-]', '').Trim()
      if ($name.Length -lt 2) { continue }
      [void]$phrases.Add($name)
      if ($c.countryToken -match '^[a-z_]+$') {
        $state = (Get-Culture).TextInfo.ToTitleCase(($c.countryToken -replace '_', ' '))
        [void]$phrases.Add("$name $state")
      }
    }
  } catch { Log "city list error: $($_.Exception.Message)" }
  return @($phrases)
}

# Wake word: say "Hey Jarvis" (or "Okay Jarvis"), alone or followed by a command
$script:wakePhrases = @('hey jarvis','okay jarvis','ok jarvis')
$script:wakeMin = 0.80      # how sure it must be before waking (raise it if it wakes by itself)
$script:wakeOn = $true
$script:wakeId = 0
$script:wakeText = ''
$script:plain = @()         # command grammars without the wake word (only on while the mic button is listening)

# The command phrases, as grammar builders (used with and without the wake word)
function New-CommandBuilders([string[]]$cities) {
  $list = @()
  $cmds = New-Object System.Speech.Recognition.Choices
  $cmds.Add([string[]]@('next song','next','skip','skip this song','previous song','go back','last song','pause','pause the music','stop the music',
                   'resume','play','play music','keep playing','volume up','louder','turn it up','volume down','quieter','turn it down',
                   'mute','unmute','like this song','I like this song','what''s playing','what song is this','who is this',
                   'cancel route','cancel the route','stop navigation','clear destination',
                   'what''s the weather','what''s the weather like','weather','how''s the weather','what''s the weather today',
                   'what''s the forecast','forecast','what''s the weather tomorrow','weather tomorrow','what''s the forecast for tomorrow',
                   'is it going to rain','will it rain today','is it going to rain tomorrow','what''s the temperature','how cold is it','how hot is it'))
  $list += ,@('cmd', (New-Object System.Speech.Recognition.GrammarBuilder $cmds))
  $nums = New-Object System.Speech.Recognition.Choices
  $nums.Add([string[]]@('ten','twenty','thirty','forty','fifty','sixty','seventy','eighty','ninety','one hundred','zero'))
  $vb = New-Object System.Speech.Recognition.GrammarBuilder
  $pre = New-Object System.Speech.Recognition.Choices; $pre.Add([string[]]@('set volume to','volume','set the volume to','volume to'))
  $vb.Append($pre); $vb.Append($nums); $vb.Append('percent', 0, 1)
  $list += ,@('vol', $vb)
  if ($cities.Count -gt 0) {
    $nb = New-Object System.Speech.Recognition.GrammarBuilder
    $pre = New-Object System.Speech.Recognition.Choices; $pre.Add([string[]]@('navigate to','take me to','drive to','go to','set destination to','route to','directions to'))
    $nb.Append($pre)
    $cc = New-Object System.Speech.Recognition.Choices; $cc.Add([string[]]$cities)
    $nb.Append($cc)
    $list += ,@('nav', $nb)
  }
  $pb = New-Object System.Speech.Recognition.GrammarBuilder 'play'
  $pb.AppendDictation()
  $list += ,@('play', $pb)
  return ,$list
}

function Initialize-Recognizer {
  if ($script:rec -or $script:recError) { return }
  try {
    $r = New-Object System.Speech.Recognition.SpeechRecognitionEngine ([System.Globalization.CultureInfo]'en-US')
    $cities = Get-AtsCityPhrases
    $wakeChoices = New-Object System.Speech.Recognition.Choices; $wakeChoices.Add([string[]]$script:wakePhrases)
    # wake word alone
    $g = New-Object System.Speech.Recognition.Grammar (New-Object System.Speech.Recognition.GrammarBuilder $wakeChoices); $g.Name = 'wake'; $r.LoadGrammar($g)
    # wake word + a command, said in one breath
    foreach ($pair in (New-CommandBuilders $cities)) {
      $wb = New-Object System.Speech.Recognition.GrammarBuilder $wakeChoices
      $wb.Append($pair[1])
      $g = New-Object System.Speech.Recognition.Grammar $wb; $g.Name = 'wake-' + $pair[0]; $r.LoadGrammar($g)
    }
    # wake word + any question (sent to Ollama by the Desk Thing), lower priority than real commands
    $ab = New-Object System.Speech.Recognition.GrammarBuilder $wakeChoices
    $ab.AppendDictation()
    $g = New-Object System.Speech.Recognition.Grammar $ab; $g.Name = 'wake-ask'; $g.Weight = 0.5; $r.LoadGrammar($g)
    # plain commands (mic button), off until /listen asks
    foreach ($pair in (New-CommandBuilders $cities)) {
      $g = New-Object System.Speech.Recognition.Grammar $pair[1]; $g.Name = $pair[0]; $g.Enabled = $false; $r.LoadGrammar($g); $script:plain += $g
    }
    $g = New-Object System.Speech.Recognition.DictationGrammar; $g.Name = 'free'; $g.Weight = 0.3; $g.Enabled = $false; $r.LoadGrammar($g); $script:plain += $g
    $r.SetInputToDefaultAudioDevice()
    Register-ObjectEvent -InputObject $r -EventName SpeechRecognized -SourceIdentifier 'deskthing-heard' | Out-Null
    $r.RecognizeAsync([System.Speech.Recognition.RecognizeMode]::Multiple)
    $script:rec = $r
    Log "assistant ready: $($cities.Count) city phrases, wake word listening"
  } catch {
    $script:recError = $_.Exception.Message
    Log "assistant unavailable: $script:recError"
  }
}

function Remove-WakeWord([string]$text) {
  foreach ($w in $script:wakePhrases) { if ($text -like "$w*") { return $text.Substring($w.Length).Trim() } }
  return $text
}

# A short "ding" so you know it's listening
$script:chime = $null
function Play-Chime {
  try {
    if (-not $script:chime) {
      $rate = 22050; $ms = New-Object System.IO.MemoryStream; $bw = New-Object System.IO.BinaryWriter($ms)
      $samples = New-Object System.Collections.Generic.List[int16]
      # a single bell-like "ding": a bright note with soft overtones that fades out
      $n = [int]($rate * 0.7)
      for ($i = 0; $i -lt $n; $i++) {
        $t = $i / $rate
        $env = [math]::Min(1, $i / 60.0) * [math]::Exp(-$t * 6)
        $v = [math]::Sin(2 * [math]::PI * 1318.5 * $t) + 0.35 * [math]::Sin(2 * [math]::PI * 2637 * $t) * [math]::Exp(-$t * 6) + 0.15 * [math]::Sin(2 * [math]::PI * 3955.5 * $t) * [math]::Exp(-$t * 10)
        $samples.Add([int16](11000 * $env * $v / 1.5))
      }
      $bw.Write([Text.Encoding]::ASCII.GetBytes('RIFF')); $bw.Write([int](36 + $samples.Count * 2)); $bw.Write([Text.Encoding]::ASCII.GetBytes('WAVEfmt '))
      $bw.Write([int]16); $bw.Write([int16]1); $bw.Write([int16]1); $bw.Write([int]$rate); $bw.Write([int]($rate * 2)); $bw.Write([int16]2); $bw.Write([int16]16)
      $bw.Write([Text.Encoding]::ASCII.GetBytes('data')); $bw.Write([int]($samples.Count * 2))
      foreach ($v in $samples) { $bw.Write($v) }
      $script:chime = $ms.ToArray()
    }
    $player = New-Object System.Media.SoundPlayer (New-Object System.IO.MemoryStream (,$script:chime))
    $player.Play()
  } catch { Log "chime error: $($_.Exception.Message)" }
}

# Look at anything the recognizer heard in the background (the wake word, then the command)
$script:awakeUntil = $null
$script:wakeState = ''
function Set-Plain([bool]$on) { foreach ($g in $script:plain) { $g.Enabled = $on } }
function Set-Wake([string]$state, [string]$text) { $script:wakeId++; $script:wakeState = $state; $script:wakeText = $text }
function Read-WakeEvents {
  foreach ($e in @(Get-Event -SourceIdentifier 'deskthing-heard' -ErrorAction SilentlyContinue)) {
    Remove-Event -EventIdentifier $e.EventIdentifier
    $res = $e.SourceEventArgs.Result
    if (-not $res -or -not $script:wakeOn) { continue }
    $name = $res.Grammar.Name
    if ($name -like 'wake*') {
      if ($res.Confidence -lt $script:wakeMin) { continue }
      Log "wake: '$($res.Text)' ($([math]::Round($res.Confidence, 2)))"
      if ($name -eq 'wake') {
        # just the wake word: chime, then listen for the command for a few seconds
        Play-Chime
        Set-Plain $true
        $script:awakeUntil = (Get-Date).AddSeconds(7)
        Set-Wake 'listening' ''
      } else {
        Set-Plain $false; $script:awakeUntil = $null
        Set-Wake 'heard' (Remove-WakeWord $res.Text)
      }
    } elseif ($script:awakeUntil) {
      Set-Plain $false; $script:awakeUntil = $null
      Set-Wake 'heard' $res.Text
    }
  }
  if ($script:awakeUntil -and (Get-Date) -gt $script:awakeUntil) {
    Set-Plain $false; $script:awakeUntil = $null
    Set-Wake 'timeout' ''
  }
}

# Microphone mute: stop the recognizer completely so the mic isn't used at all
$script:micMuted = $false
function Set-MicMuted([bool]$m) {
  if (-not $script:rec -or $m -eq $script:micMuted) { $script:micMuted = $m; return }
  $script:micMuted = $m
  if ($m) {
    try { $script:rec.RecognizeAsyncCancel() } catch {}
    Set-Plain $false; $script:awakeUntil = $null
    Log 'microphone muted'
  } else {
    for ($i = 0; $i -lt 30; $i++) {
      try { $script:rec.RecognizeAsync([System.Speech.Recognition.RecognizeMode]::Multiple); break } catch { Start-Sleep -Milliseconds 100 }
    }
    Log 'microphone on'
  }
}

function Get-WakeJson {
  Initialize-Recognizer
  return (@{ id = $script:wakeId; state = $script:wakeState; text = $script:wakeText; on = $script:wakeOn; muted = $script:micMuted; ok = [bool]$script:rec } | ConvertTo-Json -Compress)
}

function Get-ListenJson {
  Initialize-Recognizer
  if (-not $script:rec) {
    return (@{ ok = $false; error = "Speech recognition isn't available on this PC: $script:recError" } | ConvertTo-Json -Compress)
  }
  if ($script:micMuted) { return (@{ ok = $false; error = 'muted' } | ConvertTo-Json -Compress) }
  Read-WakeEvents   # clear anything older
  Set-Plain $true
  try {
    $until = (Get-Date).AddSeconds(8)
    while ((Get-Date) -lt $until) {
      $e = Wait-Event -SourceIdentifier 'deskthing-heard' -Timeout 1
      if (-not $e) { continue }
      Remove-Event -EventIdentifier $e.EventIdentifier
      $res = $e.SourceEventArgs.Result
      if (-not $res -or $res.Grammar.Name -eq 'wake') { continue }
      return (@{ ok = $true; text = (Remove-WakeWord $res.Text); grammar = $res.Grammar.Name; confidence = [math]::Round($res.Confidence, 2) } | ConvertTo-Json -Compress)
    }
    return (@{ ok = $false; error = 'nothing heard' } | ConvertTo-Json -Compress)
  } catch {
    return (@{ ok = $false; error = $_.Exception.Message } | ConvertTo-Json -Compress)
  } finally {
    if (-not $script:awakeUntil) { Set-Plain $false }
  }
}

$port = 26540
$listener = New-Object System.Net.Sockets.TcpListener([System.Net.IPAddress]::Any, $port)
try { $listener.Start() } catch { Log "could not start on port $port : $($_.Exception.Message)"; exit 1 }
Log "listening on port $port"
Initialize-Recognizer

while ($true) {
  $client = $null
  if ($script:rec -and -not $script:micMuted) { Read-WakeEvents }
  if (-not $listener.Pending()) { Start-Sleep -Milliseconds 40; continue }
  try {
    $client = $listener.AcceptTcpClient()
    $client.ReceiveTimeout = 3000
    $stream = $client.GetStream()
    $reader = New-Object System.IO.StreamReader($stream)
    $first = $reader.ReadLine()
    while (($line = $reader.ReadLine()) -ne $null -and $line -ne '') { }
    $isOptions = $first -like 'OPTIONS*'
    $target = (($first -split ' ')[1])
    $ctype = 'application/json; charset=utf-8'
    if ($isOptions) {
      $bytes = [byte[]]@()
    } elseif ($target -like '/speak*') {
      $text = Get-QueryValue $target 'text'
      if ($text.Length -gt 700) { $text = $text.Substring(0, 700) }
      if (-not $text) { $text = ' ' }
      $bytes = Get-SpeechWav $text
      $ctype = 'audio/wav'
    } elseif ($target -like '/mic*') {
      $m = Get-QueryValue $target 'mute'
      Initialize-Recognizer
      if ($m -eq '1') { Set-MicMuted $true } elseif ($m -eq '0') { Set-MicMuted $false }
      $bytes = [Text.Encoding]::UTF8.GetBytes((@{ muted = $script:micMuted; ok = [bool]$script:rec } | ConvertTo-Json -Compress))
    } elseif ($target -like '/wake*') {
      $want = Get-QueryValue $target 'on'
      if ($want -eq '0') { $script:wakeOn = $false } elseif ($want -eq '1') { $script:wakeOn = $true }
      $bytes = [Text.Encoding]::UTF8.GetBytes((Get-WakeJson))
    } elseif ($target -like '/listen*') {
      $bytes = [Text.Encoding]::UTF8.GetBytes((Get-ListenJson))
    } else {
      $bytes = [Text.Encoding]::UTF8.GetBytes((Get-OutputJson))
    }
    $head = "HTTP/1.1 " + ($(if ($isOptions) { '204 No Content' } else { '200 OK' })) + "`r`n" +
            "Content-Type: $ctype`r`n" +
            "Access-Control-Allow-Origin: *`r`nAccess-Control-Allow-Methods: GET, OPTIONS`r`nAccess-Control-Allow-Headers: *`r`n" +
            "Cache-Control: no-store`r`nContent-Length: $($bytes.Length)`r`nConnection: close`r`n`r`n"
    $hb = [Text.Encoding]::ASCII.GetBytes($head)
    $stream.Write($hb, 0, $hb.Length)
    if ($bytes.Length) { $stream.Write($bytes, 0, $bytes.Length) }
    $stream.Flush()
  } catch { Log "request error: $($_.Exception.Message)" }
  finally { if ($client) { $client.Close() } }
}
