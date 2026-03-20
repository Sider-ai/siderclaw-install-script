#!/usr/bin/env bash
set -euo pipefail

PLUGIN_NPM_SPEC_DEFAULT="@hywkp/sider"
PLUGIN_ID_DEFAULT="sider"

RUN_CONFIGURE="${RUN_CONFIGURE:-1}"
SIDER_SETUP_TOKEN="${SIDER_SETUP_TOKEN:-}"
SIDER_GATEWAY_URL="${SIDER_GATEWAY_URL:-}"
SIDER_RELAY_ID="${SIDER_RELAY_ID:-}"
SIDER_TOKEN_INPUT="${SIDER_TOKEN:-}"
SIDER_RELAY_TOKEN="${SIDER_RELAY_TOKEN:-}"
SIDER_TOKEN="${SIDER_TOKEN_INPUT:-$SIDER_RELAY_TOKEN}"

PLUGIN_NPM_SPEC="${PLUGIN_NPM_SPEC:-$PLUGIN_NPM_SPEC_DEFAULT}"
PLUGIN_ID="${PLUGIN_ID:-$PLUGIN_ID_DEFAULT}"

if ! command -v openclaw >/dev/null 2>&1; then
  echo "[install] openclaw command not found in PATH."
  echo "[install] Install OpenClaw first, then rerun this script."
  exit 1
fi

if [[ -n "${SIDER_SESSION_ID:-}" || -n "${SIDER_SESSION_KEY:-}" ]]; then
  echo "[install] SIDER_SESSION_ID and SIDER_SESSION_KEY are no longer used during installation; ignoring them."
fi

if [[ -n "$SIDER_TOKEN_INPUT" && -n "$SIDER_RELAY_TOKEN" && "$SIDER_TOKEN_INPUT" != "$SIDER_RELAY_TOKEN" ]]; then
  echo "[install] SIDER_TOKEN and SIDER_RELAY_TOKEN are both set but differ." >&2
  echo "[install] Keep only one of them, or make them identical." >&2
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

configure_common_sider_channel() {
  echo "[install] Applying common channels.sider config..."
  openclaw config set channels.sider.enabled true

  if [[ -n "$SIDER_RELAY_ID" ]]; then
    openclaw config set channels.sider.relayId "$SIDER_RELAY_ID"
  fi
}

configure_sider_setup_token_mode() {
  echo "[install] Configuring setup-token mode..."
  configure_common_sider_channel
  openclaw config set channels.sider.setupToken "$SIDER_SETUP_TOKEN"
  echo "[install] Wrote channels.sider.setupToken."
  echo "[install] The plugin will exchange it for gatewayUrl/token and remove setupToken after success."
  echo "[install] If channels.sider.gatewayUrl/token already exist, remove them first; otherwise setup-token exchange will be skipped."
}

configure_sider_direct_mode() {
  echo "[install] Configuring direct gateway mode..."
  configure_common_sider_channel
  openclaw config set channels.sider.gatewayUrl "$SIDER_GATEWAY_URL"

  if [[ -n "$SIDER_TOKEN" ]]; then
    openclaw config set channels.sider.token "$SIDER_TOKEN"
    if [[ -n "$SIDER_RELAY_TOKEN" && -z "$SIDER_TOKEN_INPUT" ]]; then
      echo "[install] Received legacy SIDER_RELAY_TOKEN; wrote channels.sider.token."
    fi
  else
    echo "[install] SIDER_TOKEN is empty; only configure gatewayUrl."
    echo "[install] This works only if the gateway does not require relay auth."
  fi
}

resolve_configure_mode() {
  local has_setup_token=0
  local has_direct_gateway=0
  local has_direct_token=0

  if [[ -n "$SIDER_SETUP_TOKEN" ]]; then
    has_setup_token=1
  fi
  if [[ -n "$SIDER_GATEWAY_URL" ]]; then
    has_direct_gateway=1
  fi
  if [[ -n "$SIDER_TOKEN" ]]; then
    has_direct_token=1
  fi

  if (( has_setup_token )) && (( has_direct_gateway || has_direct_token )); then
    echo "[install] Do not mix setup-token mode with direct gateway/token mode." >&2
    echo "[install] Use either SIDER_SETUP_TOKEN, or SIDER_GATEWAY_URL (+ optional SIDER_TOKEN)." >&2
    return 1
  fi
  if (( has_setup_token )); then
    echo "setup-token"
    return 0
  fi
  if (( has_direct_token )) && (( ! has_direct_gateway )); then
    echo "[install] SIDER_TOKEN requires SIDER_GATEWAY_URL." >&2
    return 1
  fi
  if (( has_direct_gateway )); then
    echo "direct"
    return 0
  fi
  echo "none"
}

if [[ "$RUN_CONFIGURE" = "0" ]]; then
  echo "[install] RUN_CONFIGURE=0, skipped channel configuration."
else
  configure_mode="$(resolve_configure_mode)"
  case "$configure_mode" in
    setup-token)
      configure_sider_setup_token_mode
      ;;
    direct)
      configure_sider_direct_mode
      ;;
    none)
      echo "[install] No channels.sider configuration was applied."
      echo "[install] To use setup-token mode:"
      echo "  curl -fsSL https://raw.githubusercontent.com/Sider-ai/siderclaw-install-script/main/sider-openclaw-plugin/install-openclaw-plugin.sh | SIDER_SETUP_TOKEN='<one-time-token>' bash"
      echo "[install] To use direct gateway mode:"
      echo "  curl -fsSL https://raw.githubusercontent.com/Sider-ai/siderclaw-install-script/main/sider-openclaw-plugin/install-openclaw-plugin.sh | SIDER_GATEWAY_URL='https://<gateway-url>' SIDER_TOKEN='<access-token>' bash"
      ;;
  esac
fi

echo "[install] Suggested checks:"
echo "  openclaw channels list"
echo "  openclaw status --json"
echo "[install] Done."
