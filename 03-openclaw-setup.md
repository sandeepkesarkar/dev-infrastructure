# OpenClaw Setup Guide

<!--
AGENT CONTEXT
=============
Purpose: Install and configure OpenClaw as an always-on local AI assistant daemon on the Mac Mini.

How to use this guide with a user:
  1. Confirm the user has completed 02-terminal-setup.md (Homebrew must be installed).
  2. Walk through Steps 1–5 in order — each step must succeed before the next.
  3. Step 6 (companion app) and Step 7 (sandboxing note) are optional — offer them after the core setup is verified.

At each "Verify" block: confirm the step worked before moving on.

Key terms used throughout:
  Gateway  = the OpenClaw daemon process that runs in the background and handles all channel traffic
  Channel  = a messaging platform OpenClaw connects to (Telegram, WhatsApp, iMessage, etc.)
  Pairing  = the one-time approval flow that links your account on a channel to the Gateway
-->

## What You're Building

OpenClaw is a locally-run AI assistant daemon that connects to messaging platforms and routes your messages to an AI model. By the end of this guide, you'll have:

- A persistent Gateway daemon that starts automatically on login
- OpenAI configured as the AI model
- Telegram connected as your first messaging channel

You talk to the assistant by messaging your Telegram bot. The Gateway handles everything in between.

> **Prerequisite:** Complete the [Terminal Setup](02-terminal-setup.md) guide first. Homebrew must be installed.

---

## Step 1 — Install Node.js via nvm

OpenClaw requires Node 22.16 or later. `nvm` (Node Version Manager) lets you install and switch Node versions without touching your system Node, and is the recommended approach.

**Install nvm:**

```bash
curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.7/install.sh | bash
```

Close and reopen your terminal, or reload your shell:

```bash
source ~/.zshrc
```

**Install Node 24 (recommended):**

```bash
nvm install 24
nvm use 24
nvm alias default 24
```

Setting `default` means Node 24 is automatically active in every new terminal session.

**Verify:**

```bash
node --version
```

You should see `v24.x.x`. Also confirm npm is available:

```bash
npm --version
```

---

## Step 2 — Install OpenClaw

Install the OpenClaw CLI globally:

```bash
npm install -g openclaw@latest
```

**Verify:**

```bash
openclaw --version
```

You should see the installed version number.

---

## Step 3 — Configure OpenAI as Your Model

This step stores your OpenAI API key securely and registers it with OpenClaw via its interactive setup wizard.

**Store your API key in macOS Keychain:**

Storing the key in `~/.zshrc` as plaintext means any process that reads your shell files can see it. Instead, store it in the macOS Keychain — encrypted on disk and protected by your login password.

Run this once to save the key (replace `your-api-key-here` with your actual key):

```bash
security add-generic-password -a "$USER" -s "OPENAI_API_KEY" -w "your-api-key-here"
```

Then add this to `~/.zshrc` so the key is loaded into your environment at login without ever being written to the file itself:

```bash
echo 'export OPENAI_API_KEY=$(security find-generic-password -a "$USER" -s "OPENAI_API_KEY" -w 2>/dev/null)' >> ~/.zshrc
source ~/.zshrc
```

To update the key later, delete the old entry and add a new one:

```bash
security delete-generic-password -a "$USER" -s "OPENAI_API_KEY"
security add-generic-password -a "$USER" -s "OPENAI_API_KEY" -w "your-new-key-here"
```

> **Note:** If you don't have an OpenAI account yet, sign up at [platform.openai.com](https://platform.openai.com) and create an API key under API Keys. Usage is billed per token.

**Run the model setup wizard:**

OpenClaw requires the API key to be registered in its own auth store — setting `$OPENAI_API_KEY` in your shell is not enough on its own. Run the interactive wizard:

```bash
openclaw configure --section model
```

Walk through the prompts as follows:

1. **Where will the Gateway run?** → Select **Local (this machine)**, press Enter
2. **Model/auth provider** → Select **OpenAI**, press Enter
3. **OpenAI auth method** → Select **OpenAI API Key**, press Enter
4. **Use existing OPENAI_API_KEY?** → Select **Yes**, press Enter
5. **Models in /model picker** → Press Enter to skip (no additional models needed)

The wizard will set the default model and create `~/.openclaw/agents/main/agent/auth-profiles.json` with your credentials.

**Lock down the config file:**

The `openclaw.json` file will eventually hold your Telegram bot token. Restrict it to your user only:

```bash
chmod 600 ~/.openclaw/openclaw.json
```

**Verify:**

```bash
openclaw agent --agent main --message "say hello"
```

> **First run only — bootstrap prompt:** On the very first message, OpenClaw will respond with a setup prompt instead of answering your question. This is expected:
>
> ```
> Hey. I just came online. Who am I? Who are you?
>
> Bootstrap isn't complete yet — I still need:
> - my name
> - my nature (assistant, ghost, gremlin, whatever fits)
> - my vibe
> - my emoji
> - your name and what to call you
>
> Simplest next step: reply with something like:
>
> You're: Nova / machine familiar / warm and sharp / 🌙
> I'm: Sandeep / call me Sandeep
> ```
>
> Answer it using this format (customise as you like):
>
> ```bash
> openclaw agent --agent main --message "You're: Assistant / AI assistant / helpful and direct / 🤖 I'm: Sandeep / call me Sandeep"
> ```
>
> After that, the agent responds to messages normally.

If you see an authentication error, confirm the key loaded correctly:

```bash
echo $OPENAI_API_KEY
```

---

## Step 4 — Install the Gateway Daemon

The Gateway is the background process that keeps OpenClaw running at all times, receives messages from connected channels, and sends them to the model. Installing it as a daemon means it starts automatically on login without you doing anything.

**Before running the installer, create a Telegram bot:**

The installer wizard will ask for your Telegram bot token, so create the bot first.

1. Open Telegram on your phone or desktop and search for **@BotFather**
2. Start a chat and send `/newbot`
3. Follow the prompts — you'll be asked for a bot display name and a username (the username must end in `bot`, e.g. `myassistant_bot`)
4. BotFather will reply with a **bot token** that looks like `1234567890:ABCdefGHIjklMNOpqrsTUVwxyz`
5. Copy and save that token — you'll paste it into the wizard below

**Run the installer:**

```bash
openclaw onboard --install-daemon
```

Walk through the prompts as follows:

1. **Setup mode** → Select **QuickStart**, press Enter
2. **Config handling** → Select **Use existing values**, press Enter
3. **Model/auth provider** → Select **OpenAI**, press Enter
4. **OpenAI auth method** → Select **OpenAI API Key**, press Enter
5. **Use existing OPENAI_API_KEY?** → Select **Yes**, press Enter
6. **Select channel** → Select **Telegram (Bot API)**, press Enter
7. **How to provide Telegram bot token** → Select **Enter Telegram bot token**, press Enter
8. **Enter Telegram bot token** → Paste your token from BotFather, press Enter
9. **Search provider** → Select **Skip for now**, press Enter
10. **Configure skills now?** → Select **No**, press Enter
11. **Enable hooks?** → Press **Space** to select **Skip for now**, then press Enter
12. **Gateway service already installed** → Select **Restart**, press Enter
13. **How do you want to hatch your bot?** → Select **Hatch in Terminal**, press Enter

The terminal will then show the agent's bootstrap prompt — see Step 3's verify section for how to respond to it.

**Verify the Gateway is only listening on localhost:**

The Gateway should not be reachable from other machines on your network. Check what address it's bound to:

```bash
lsof -i :18789 | grep LISTEN
```

Look at the `NAME` column in the output:

- `localhost:18789` or `127.0.0.1:18789` — the Gateway is only reachable from your Mac. You're good.
- `*:18789` — the Gateway is reachable from any machine on your network. In this case, add a firewall rule to block the port:

```bash
/usr/libexec/ApplicationFirewall/socketfilterfw --add $(which openclaw)
```

Then open **System Settings → Network → Firewall → Options** and confirm OpenClaw is listed as "Block incoming connections."

**Stopping the daemon:**

To stop the Gateway at any time:

```bash
openclaw gateway stop
```

The daemon will restart automatically on next login since it is installed as a launchd service.

---

## Step 5 — Pair Your Telegram Account

The bot token is now configured, but the bot won't respond to anyone by default — this is controlled by the `dmPolicy: pairing` setting the wizard applied. You need to approve your own Telegram account before the bot will reply to you.

In a second terminal window, send a message to your bot on Telegram (just `/start` is enough), then check for the pending pairing request:

```bash
openclaw pairing list telegram
```

Approve your account using the pairing code shown:

```bash
openclaw pairing approve telegram <CODE>
```

> **What pairing does:** It links your specific Telegram account to the Gateway. Anyone else who finds your bot username will get no response until you explicitly approve them — keeping the bot private.

**Verify:** Send a message to your Telegram bot. You should receive an AI-generated reply within a few seconds.

---

## Step 6 — macOS Companion App *(Optional)*

The OpenClaw companion app for macOS adds voice support with wake-word detection ("Hey Claw" or a custom phrase), a live canvas workspace, and a menu bar icon showing Gateway status.

Download it from [github.com/openclaw/openclaw](https://github.com/openclaw/openclaw) under the Releases section and install it like any `.dmg`. The companion app connects automatically to the running Gateway.

---

## Step 7 — Sandboxing *(Optional — future guide)*

By default, any tools OpenClaw uses run directly on your Mac. For group channels (shared Slack workspaces, Discord servers, etc.) where other users can interact with the bot, you should enable sandboxing so tool execution is isolated from your host system. This requires Docker.

Sandboxing setup is covered in a separate guide. Until then, keep OpenClaw to private DM channels where you control who can interact with it.

---

## Verification Checklist

- [ ] `node --version` shows `v24.x.x`
- [ ] `npm --version` returns a version number
- [ ] `openclaw --version` returns a version number
- [ ] `~/.openclaw/openclaw.json` exists with the `agents.defaults.model` and Telegram channel config
- [ ] `ls -l ~/.openclaw/openclaw.json` shows permissions `-rw-------` (600)
- [ ] `security find-generic-password -a "$USER" -s "OPENAI_API_KEY" -w` returns your API key
- [ ] `echo $OPENAI_API_KEY` prints your API key (not empty)
- [ ] `openclaw configure --section model` completed (wizard registers the key in OpenClaw's auth store)
- [ ] `openclaw agent --agent main --message "say hello"` returns a response from the model
- [ ] `openclaw onboard --install-daemon` wizard completed — Telegram token entered, daemon restarted
- [ ] Bootstrap prompt answered — agent responds normally to messages
- [ ] `lsof -i :18789 | grep LISTEN` shows `localhost:18789` or `127.0.0.1:18789`, not `*:18789`
- [ ] `openclaw pairing approve telegram <CODE>` completed
- [ ] Sending a message to your Telegram bot returns an AI reply
