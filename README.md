# 🛡️ Agent Quota Shield for Omarchy

## Marketplace installation and review notes

This section describes the current implementation and takes precedence over broader feature claims below.

### Requirements and dependencies

Requires Omarchy Quattro's plugin-capable shell, Qt 6 / QtQuick / QtQuick.Controls / QtQuick.Layouts, Quickshell and Omarchy qs.Commons / qs.Ui modules. This is not a standalone QML application.

Bash, Python 3, jq, grep, sed, GNU coreutils and foot. Requires a separately configured tokenshield installation (at `$TOKENSHIELD_DIR`, `~/.local/share/tokenshield`, or `~/Work/tokenshield`) providing `rag_compressor.py` and `dashboard.py`; these are not bundled or installed.

### Install

Review the unsandboxed plugin source, then run in an Omarchy Quattro session:

    omarchy plugin add https://github.com/harshithnadig/omarchy-agent-shield.git --enable

Use the Omarchy bar editor to place the widget if necessary. Installation fetches upstream HEAD, not a pinned marketplace-reviewed snapshot.

### Remove

    omarchy plugin remove harshith.agent-shield

### Permissions and persistent state

Reads `~/.codex/config.toml`; preset buttons request edits to
`auto_compact_token_limit`. Routing controls start/stop only a gateway whose
PID is stored in a private `$XDG_RUNTIME_DIR/tokenshield` directory and whose
`/proc/<pid>/cmdline` still names the configured `rag_compressor.py`. The
dashboard opens foot. Back up Codex configuration before using presets.
Removal does not restore configuration or stop a separately running gateway.

### Current limitations

Prototype. TokenShield telemetry is shown only when valid, bounded local JSON
is present; otherwise the panel displays unavailable values rather than sample
metrics. The plugin does not authenticate the gateway or prove that a remote
provider is safe. Codex configuration changes remain user-controlled and are
not automatically restored on removal.

Repository structure and documentation were reviewed for resubmission. This is not a fresh end-to-end runtime test or security audit.

### License

MIT; see LICENSE. External applications, models and dependencies retain their own licenses.

---

Visual 1-Click Control Panel for AI Agents in Omarchy:
- 🔀 **1-Click OmniRoute Master Toggle:** Switch between direct native API and multi-provider failover.
- 🍃 **1-Click Preset Buttons:** Switch between Super Lean (8k), Default (12k), and Balanced (16k) token compaction.
- 🤖 **Agent Health Vitals:** Live telemetry for Antigravity, Codex CLI, and ChatGPT Desktop.
