# Contributing to siderclaw-install-script

This repo hosts component binaries and `manifest.json`, which the OpenClaw Console updater reads to dynamically discover and update components.

## manifest.json

The updater fetches this file on every check cycle. Adding a component here makes it appear in the Console UI; removing it hides it (but does **not** stop the service or delete the binary — uninstalling is the install-script's responsibility).

### Structure

```jsonc
{
  "components": {
    "<component-id>": {
      "version": "0.2.0",
      "display_name": "Human-Readable Name",
      "binary": "filename-in-this-repo",
      "service": "systemd-unit-name",
      "hooks": [              // optional
        {
          "file": "script-in-this-repo.sh",
          "args": ["{{.OpenclawHome}}"]
        }
      ]
    }
  }
}
```

### Field reference

| Field | Required | Description |
|---|---|---|
| `version` | yes | Semantic version string. The updater compares this against the locally installed version to determine if an update is available. |
| `display_name` | yes | Shown in the Console UI. |
| `binary` | yes | Filename of the binary **in this repo**. The updater downloads it via the GitHub Contents API. |
| `service` | yes | The `systemd --user` unit name. After updating, the updater runs `systemctl --user restart <service>`. This is also used as the local binary filename under `~/bin/<service>`. |
| `hooks` | no | List of post-update hooks (see below). |

### Hooks

Hooks run **after** the binary is replaced and **before** the service is restarted. Each hook downloads a script from this repo, writes it to a temp file, and executes it.

| Hook field | Description |
|---|---|
| `file` | Script filename in this repo. |
| `args` | Arguments passed to the script. Supports template variables (see below). |

### Template variables

Available in hook `args`:

| Variable | Resolves to | Example |
|---|---|---|
| `{{.OpenclawHome}}` | `$OPENCLAW_HOME/.openclaw` (or `~/.openclaw` if unset) | `/home/user/.openclaw` |
| `{{.BinDir}}` | `~/bin` — the directory where binaries are installed | `/home/user/bin` |

## Adding a new component

1. **Build the binary** for `linux-amd64` and commit it to this repo.
2. **Add an entry** to `manifest.json` under `components`.
3. **If your component needs post-install setup**, write a shell script, commit it to this repo, and reference it in `hooks`.
4. **Open a PR**. Once merged, the updater will pick up the new component on its next check cycle (~10 min) and show it as `update_available` in the Console UI. Users install it by clicking Update.

### Example: adding a new component

```json
{
  "components": {
    "my-new-service": {
      "version": "1.0.0",
      "display_name": "My New Service",
      "binary": "my-new-service-linux-amd64",
      "service": "my-new-service"
    }
  }
}
```

Ensure a matching systemd user unit (`~/.config/systemd/user/my-new-service.service`) is provisioned by the install script or a hook.

## Updating a component version

1. Replace the binary file in this repo with the new build.
2. Bump the `version` field in `manifest.json`.
3. Open a PR.

## Conventions

- **Component ID** (the JSON key): lowercase, hyphen-separated, e.g. `browser-mcp`. This is the stable identifier used for state persistence.
- **Binary naming**: `<name>-linux-amd64` by convention.
- **Service naming**: must match the systemd unit name exactly. Only `[a-zA-Z0-9._-]` characters are allowed.
- **Hooks should be idempotent**: the updater may re-run them on retry.
