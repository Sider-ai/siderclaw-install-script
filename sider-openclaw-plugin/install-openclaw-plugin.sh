#!/usr/bin/env bash
set -euo pipefail

PLUGIN_NPM_SPEC_DEFAULT="@hywkp/sider"
PLUGIN_ID_DEFAULT="sider"

RUN_CONFIGURE="${RUN_CONFIGURE:-1}"
SIDER_GATEWAY_URL="${SIDER_GATEWAY_URL:-http://127.0.0.1:8080}"
SIDER_SESSION_KEY="${SIDER_SESSION_KEY:-}"
SIDER_SESSION_ID="${SIDER_SESSION_ID:-$SIDER_SESSION_KEY}"
SIDER_RELAY_ID="${SIDER_RELAY_ID:-}"
SIDER_RELAY_TOKEN="${SIDER_RELAY_TOKEN:-}"

PLUGIN_NPM_SPEC="${PLUGIN_NPM_SPEC:-$PLUGIN_NPM_SPEC_DEFAULT}"
PLUGIN_ID="${PLUGIN_ID:-$PLUGIN_ID_DEFAULT}"

if ! command -v openclaw >/dev/null 2>&1; then
  echo "[install] openclaw command not found in PATH."
  echo "[install] Install OpenClaw first, then rerun this script."
  exit 1
fi

echo "[install] Installing plugin from npm package..."
echo "[install] npm spec: $PLUGIN_NPM_SPEC"
set +e
install_output="$(openclaw plugins install "$PLUGIN_NPM_SPEC" 2>&1)"
install_rc=$?
set -e

if [[ $install_rc -eq 0 ]]; then
  if [[ -n "$install_output" ]]; then
    echo "$install_output"
  fi
  echo "[install] Plugin install done."
elif [[ "$install_output" == *"plugin already exists:"* ]]; then
  echo "$install_output"
  echo "[install] Plugin already installed; trying upgrade..."
  set +e
  # Auto-accept integrity-drift prompt for non-interactive installer runs.
  update_output="$(printf 'y\n' | openclaw plugins update "$PLUGIN_ID" 2>&1)"
  update_rc=$?
  set -e
  update_failed=0
  if [[ $update_rc -ne 0 ]]; then
    update_failed=1
  elif echo "$update_output" | grep -Eiq "Failed to (update|check)|aborted:"; then
    update_failed=1
  fi

  if [[ $update_failed -eq 0 ]]; then
    if [[ -n "$update_output" ]]; then
      echo "$update_output"
    fi
    echo "[install] Plugin upgrade done."
  else
    if [[ -n "$update_output" ]]; then
      echo "$update_output" >&2
    fi
    echo "[install] Plugin upgrade failed; continuing to channel configuration update."
  fi
else
  if [[ -n "$install_output" ]]; then
    echo "$install_output" >&2
  fi
  echo "[install] Plugin install failed."
  exit "$install_rc"
fi

configure_sider_channel() {
  echo "[install] Applying channels.sider config..."
  openclaw config set channels.sider.enabled true
  openclaw config set channels.sider.gatewayUrl "$SIDER_GATEWAY_URL"

  if [[ -n "$SIDER_RELAY_ID" ]]; then
    openclaw config set channels.sider.relayId "$SIDER_RELAY_ID"
  fi
  if [[ -n "$SIDER_RELAY_TOKEN" ]]; then
    openclaw config set channels.sider.relayToken "$SIDER_RELAY_TOKEN"
  fi

  if [[ -n "$SIDER_SESSION_ID" ]]; then
    openclaw config set channels.sider.sessionId "$SIDER_SESSION_ID"
    # Keep old key for compatibility with older plugin versions.
    openclaw config set channels.sider.sessionKey "$SIDER_SESSION_ID"
    openclaw config set channels.sider.defaultTo "session:$SIDER_SESSION_ID"
  else
    echo "[install] SIDER_SESSION_ID is empty; skip sessionId/sessionKey/defaultTo."
    echo "[install] Relay monitor will receive all sessions by default."
    echo "[install] To set a default outbound session later:"
    echo "  openclaw config set channels.sider.defaultTo 'session:<your-session-id>'"
    echo "[install] If old config still contains channels.sider.sessionId/sessionKey, remove them manually to stop legacy single-session filtering."
  fi
}

if [[ "$RUN_CONFIGURE" = "0" ]]; then
  echo "[install] RUN_CONFIGURE=0, skipped channel configuration."
else
  configure_sider_channel
fi

echo "[install] Suggested checks:"
echo "  openclaw channels list"
echo "  openclaw status --json"
echo "[install] Done."
