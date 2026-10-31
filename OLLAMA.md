# Connecting Jarvis to Ollama

Jarvis handles music, navigation and weather on its own. With Ollama connected, **anything else you ask goes to your own local AI model** and the answer is spoken back. For example: "Hey Jarvis, how far is Denver from Chicago?" or "Hey Jarvis, what's a good name for a truck?"

Everything stays on your home network. Nothing goes to the cloud.

```
"Hey Jarvis, ..."  →  PC microphone (Windows speech recognition)
                   →  Desk Thing: a built-in command? → music / map / weather
                                  anything else?       → Ollama on your network → spoken answer
```

## What you need

- A computer on the same Wi-Fi/network running **[Ollama](https://ollama.com)**. An old laptop works; it doesn't need a graphics card.
- At least one model pulled on it.

## 1. Pick a model

Small models answer fastest on older hardware. On a laptop without a usable GPU (CPU only):

| Model | Pull command | Speed on an older laptop | Notes |
| --- | --- | --- | --- |
| Qwen 2.5 1.5B | `ollama pull qwen2.5:1.5b` | a few seconds | **Recommended.** Good balance of speed and sense |
| Llama 3.2 1B | `ollama pull llama3.2:1b` | fastest | Shorter, simpler answers |
| Llama 3.2 3B | `ollama pull llama3.2:3b` | slower (10–20 s) | Better answers if you can wait |

Test it on that computer:

```
ollama run qwen2.5:1.5b "Say hello in one sentence."
```

## 2. Let other devices reach Ollama

By default Ollama only answers the computer it's running on. Jarvis runs in the Desk Thing's browser, so Ollama needs to accept requests from your network **and** from a web page.

### On Windows

Open **PowerShell** and run:

```powershell
setx OLLAMA_HOST "0.0.0.0"
setx OLLAMA_ORIGINS "*"
```

Then **quit Ollama** (right-click its icon by the clock → Quit Ollama) and start it again from the Start menu, so it picks up the new settings.

Allow it through Windows Firewall. Open **PowerShell as administrator** and run:

```powershell
New-NetFirewallRule -DisplayName "Ollama" -Direction Inbound -Protocol TCP -LocalPort 11434 -Action Allow -Profile Private
```

(Your Wi-Fi needs to be set as a **Private** network in Windows for this rule to apply.)

### On Linux

```bash
sudo systemctl edit ollama.service
```

The editor opens blank. That's normal. Add these lines, then save and exit:

```ini
[Service]
Environment="OLLAMA_HOST=0.0.0.0"
Environment="OLLAMA_ORIGINS=*"
```

```bash
sudo systemctl daemon-reload
sudo systemctl restart ollama
sudo ufw allow 11434/tcp    # only if you use ufw
```

## 3. Find the computer's address

- **Windows:** run `ipconfig` and look for **IPv4 Address** (for example `192.168.1.60`).
- **Linux:** run `hostname -I`.

Tip: in your router's settings, give this computer a **reserved (static) IP** so the address never changes.

## 4. Check it works

On the Desk Thing phone (or any other device), open a browser and go to:

```
http://192.168.1.60:11434
```

(use your address). You should see **"Ollama is running"**.

## 5. Keep the computer awake

Jarvis can only ask Ollama while that computer is on and awake.

- **Windows:** Settings → System → Power → set **Sleep** to **Never** when plugged in. For a laptop, Control Panel → Power Options → **Choose what closing the lid does** → **Do nothing** when plugged in.
- Ollama starts with Windows by default, so it's ready after a restart.

## 6. Turn it on in the Desk Thing

On the Desk Thing, open **Settings** (gear, or Apps → Settings):

- **Ollama address:** the computer's address, for example `192.168.1.60` (the port `11434` is added for you)
- **Ollama model:** for example `qwen2.5:1.5b`, or leave blank to use the first model installed

Press **Cancel** (or **Connect**) to close Settings. That saves it.

## Using it

- **"Hey Jarvis"** (wait for the ding) **"how far is Denver from Chicago"**, or say it all in one breath
- Tap the **mic** button and ask
- Or **type** a question in the Jarvis panel

While it works, the panel shows **Thinking…**. Answers are kept to one to three sentences so they're quick to hear. Jarvis remembers the last few questions, so follow-ups like "and how long would that take in a truck?" make sense.

Built-in commands (skip, volume, navigate to, weather, mute…) never go to Ollama, so they stay instant.

## Troubleshooting

| What happens | What to check |
| --- | --- |
| "I couldn't reach Ollama. Is the laptop on?" | The computer is asleep or off, the address is wrong, or step 2 (OLLAMA_HOST / firewall) isn't done. Try step 4. |
| Step 4 works in a browser but Jarvis still can't reach it | `OLLAMA_ORIGINS` isn't set. Redo step 2 and restart Ollama. |
| "Ollama took too long to answer" | The model is too big for that computer. Try `qwen2.5:1.5b` or `llama3.2:1b`. The first question after a while is slower because the model has to load. |
| Jarvis hears the question wrong | Windows dictation isn't great with unusual words. Speak clearly, or type the question. |

**Security note:** with these settings, any device on your home network can use that Ollama server. That's fine on a home network, but don't forward port 11434 on your router.
