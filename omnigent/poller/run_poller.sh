#!/bin/bash
# Fires the poller agent once. Invoked hourly by launchd
# (~/Library/LaunchAgents/ai.omnigent.poller.plist) and available for a
# manual on-demand run: bash omnigent/poller/run_poller.sh
#
# Why launchd and not Omnigent's own scheduled-tasks feature: that feature's
# POST /v1/scheduled-tasks requires an authenticated "owner" identity this
# single-user local server was never logged into (no accounts/OIDC set up).
# See specs/omnigent-setup.md for the full reasoning.
set -euo pipefail

export PATH="$HOME/.local/bin:$PATH"
cd "$HOME/src/dev-infrastructure"

omnigent run omnigent/poller/config.yaml --no-log \
  -p "Run your standard poll: check for agent-ready issues on dev-infrastructure, claim and dispatch any found."
