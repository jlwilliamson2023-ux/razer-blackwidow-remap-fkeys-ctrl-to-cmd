# Razer Keyboard → macOS Setup (F-keys + Ctrl→Cmd)

[![ShellCheck](https://github.com/jlwilliamson2023-ux/razer-keyboard-macos-fkeys-ctrl-to-cmd/actions/workflows/shellcheck.yml/badge.svg)](https://github.com/jlwilliamson2023-ux/razer-keyboard-macos-fkeys-ctrl-to-cmd/actions/workflows/shellcheck.yml)
![macOS](https://img.shields.io/badge/macOS-13%2B-blue)
![License: MIT](https://img.shields.io/badge/License-MIT-green)

Production-grade, one-command setup that makes **any Razer keyboard** behave like a Mac keyboard (originally built for the BlackWidow V4):

- **F1–F12 → macOS media functions** (brightness, Mission Control, volume, etc.)
- **Control → Command** remapping for a native Mac workflow

Everything is **scoped to Razer keyboards** by USB Vendor ID `0x1532` — which *every* Razer device shares, so it works on any model (BlackWidow, Huntsman, Ornata, etc.) — and works identically over **2.4GHz dongle, Bluetooth, and USB-C wired**. Your built-in MacBook keyboard is never touched.

---

## What it does

When you plug a Razer keyboard into a Mac, two things feel "off" coming from a PC layout:

1. **The F-row types F1–F12** instead of doing brightness / volume / Mission Control like a Mac keyboard.
2. **Control is where your thumb expects Command**, so all the muscle-memory shortcuts (copy, paste, save, quit…) land on the wrong key.

This setup fixes both, automatically and permanently:

- **F1–F12 act as the macOS media keys** — brightness, Mission Control, Launchpad, keyboard light, playback, volume, mute — exactly like a built-in Mac keyboard. (Hold `fn` to get a real F-key when an app needs one.)
- **Left & Right Control behave as Command** — so `Ctrl+C / V / Z / S / Q` work as `Cmd+C / V / Z / S / Q`, the Mac way.
- **Only your Razer keyboard is affected.** Matching is by Razer's vendor ID, so your MacBook's built-in keyboard and any non-Razer keyboard are left exactly as they are.
- **Works on every connection mode** — 2.4GHz dongle, Bluetooth, and USB-C wired — with no reconfiguring when you switch.
- **Survives reboots and logins** automatically (no need to re-run anything).

### Razer Synapse is **not** required

This works entirely through macOS itself (the built-in `hidutil` driver remap) plus [Karabiner-Elements](https://karabiner-elements.pqrs.org/). You do **not** need Razer Synapse installed or running for any of it — it keeps working with Synapse closed, uninstalled, or never set up. (If you *do* use Synapse, just avoid remapping the same keys there to prevent a conflict.)

---

## Why two layers?

| Layer | Handles | Persists across reboot |
|-------|---------|------------------------|
| **hidutil** (HID driver) | Control → Command at the hardware level, before any app loads | Yes — via a LaunchAgent |
| **Karabiner-Elements** | F1–F12 → media functions + Control → Command (backup) | Yes — config on disk |

hidutil sits *below* Karabiner, so there is no double-mapping. The two layers also cover each other: hidutil applies to whatever Razer device is present at login, and Karabiner's device condition is evaluated **live**, so hot-swapping connection modes mid-session keeps working.

### Scoped by Vendor ID, not Product ID

Each connection mode (dongle / Bluetooth / wired) enumerates with a **different product ID** but the **same vendor ID** (`0x1532`). Matching on the vendor ID is what lets a single config cover all three modes at once.

> Only the keyboard emits F-key and Control keycodes, so even if you own other Razer gear (mouse, headset, etc.) sharing vendor `0x1532`, the remap only ever takes effect on the keyboard.

---

## Requirements

- macOS 13 (Ventura) or later
- [Karabiner-Elements](https://karabiner-elements.pqrs.org/) installed
- Any Razer keyboard (any connection mode)

No Homebrew, Python, or `jq` required — the installer uses only tools built into macOS.

---

## Quick Start

```bash
# 1. Install Karabiner-Elements first: https://karabiner-elements.pqrs.org/
# 2. Save install.sh to your Mac, then run:
bash install.sh
```

**One-time permission:** when prompted, grant Karabiner **Input Monitoring** access
(System Settings → Privacy & Security → Input Monitoring → toggle on Karabiner-Elements).
This is a macOS security requirement and cannot be scripted.

That's it — no manual rule-toggling in Karabiner. The installer:

- Writes and **auto-enables** both Karabiner rules (injected directly into `karabiner.json`)
- Installs the hidutil remap and makes it permanent via a LaunchAgent
- Sets the macOS F-key preference
- Backs up any existing Karabiner config first
- Is **idempotent** — safe to re-run; it won't create duplicates

### Using it on another Mac

All Razer keyboards share the same vendor ID, so the exact same `install.sh` works on any Mac and any Razer model with no edits. Install Karabiner, run the script, grant the permission once.

---

## The installer

Save this as `install.sh`:

```bash
#!/usr/bin/env bash
# install.sh — Razer Keyboard macOS Setup (F-keys + Control→Command)
# Fully automated: no manual Karabiner UI steps required.
#
# Works with ANY Razer keyboard: scopes ALL remapping to Razer's Vendor ID
# 0x1532 (5426) — shared by every Razer device — so it applies regardless of
# model and works identically over 2.4GHz dongle, Bluetooth, and USB-C wired,
# while never touching the built-in MacBook keyboard or other devices.
#
# Tested on macOS 13 Ventura and later.
# Usage: bash install.sh

# Color codes are intentionally embedded in printf format strings below.
# shellcheck disable=SC2059

set -euo pipefail

# Razer USA, Ltd. vendor id — shared by ALL connection modes (dongle/BT/wired)
RAZER_VENDOR_ID_HEX=0x1532   # hex, for the immediate hidutil call

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'; NC='\033[0m'
log()  { printf "${GREEN}✓${NC}  %s\n" "$1"; }
warn() { printf "${YELLOW}⚠${NC}  %s\n" "$1"; }
fail() { printf "${RED}✗${NC}  %s\n" "$1" >&2; exit 1; }
step() { printf "\n${BLUE}▶${NC}  %s\n" "$1"; }

# ── Preflight ─────────────────────────────────────────────────────────────────

step "Checking prerequisites"

[[ "$(uname)" == "Darwin" ]] || fail "This script is macOS only."

if [[ ! -d "/Applications/Karabiner-Elements.app" ]]; then
  warn "Karabiner-Elements not found."
  warn "Download: https://karabiner-elements.pqrs.org/ — install it, then re-run."
  exit 1
fi
log "Karabiner-Elements found"

# ── Stop Karabiner before editing its config ──────────────────────────────────

step "Stopping Karabiner-Elements"

pkill -x "Karabiner-Elements" 2>/dev/null || true
pkill -f "karabiner_console_user_server" 2>/dev/null || true
pkill -f "karabiner_observer" 2>/dev/null || true
pkill -f "karabiner_grabber" 2>/dev/null || true
sleep 1
log "Karabiner stopped"

# ── Write Karabiner complex_modifications rule files ──────────────────────────
#
# Every manipulator carries a device_if condition on vendor_id 5426, so the
# rule only fires for the Razer keyboard regardless of how it is connected.

step "Writing Karabiner rule files"

KARABINER_DIR="$HOME/.config/karabiner/assets/complex_modifications"
mkdir -p "$KARABINER_DIR"

cat > "$KARABINER_DIR/razer_f_keys.json" <<'JSON'
{
  "title": "Razer Keyboard - MacBook F-Keys",
  "rules": [{
    "description": "Razer Keyboard F-Keys to MacBook Functions",
    "manipulators": [
      {"type":"basic","from":{"key_code":"f1"}, "to":[{"key_code":"f1", "modifiers":["fn"]}],"conditions":[{"type":"device_if","identifiers":[{"vendor_id":5426}]}]},
      {"type":"basic","from":{"key_code":"f2"}, "to":[{"key_code":"f2", "modifiers":["fn"]}],"conditions":[{"type":"device_if","identifiers":[{"vendor_id":5426}]}]},
      {"type":"basic","from":{"key_code":"f3"}, "to":[{"key_code":"f3", "modifiers":["fn"]}],"conditions":[{"type":"device_if","identifiers":[{"vendor_id":5426}]}]},
      {"type":"basic","from":{"key_code":"f4"}, "to":[{"key_code":"f4", "modifiers":["fn"]}],"conditions":[{"type":"device_if","identifiers":[{"vendor_id":5426}]}]},
      {"type":"basic","from":{"key_code":"f5"}, "to":[{"key_code":"f5", "modifiers":["fn"]}],"conditions":[{"type":"device_if","identifiers":[{"vendor_id":5426}]}]},
      {"type":"basic","from":{"key_code":"f6"}, "to":[{"key_code":"f6", "modifiers":["fn"]}],"conditions":[{"type":"device_if","identifiers":[{"vendor_id":5426}]}]},
      {"type":"basic","from":{"key_code":"f7"}, "to":[{"key_code":"f7", "modifiers":["fn"]}],"conditions":[{"type":"device_if","identifiers":[{"vendor_id":5426}]}]},
      {"type":"basic","from":{"key_code":"f8"}, "to":[{"key_code":"f8", "modifiers":["fn"]}],"conditions":[{"type":"device_if","identifiers":[{"vendor_id":5426}]}]},
      {"type":"basic","from":{"key_code":"f9"}, "to":[{"key_code":"f9", "modifiers":["fn"]}],"conditions":[{"type":"device_if","identifiers":[{"vendor_id":5426}]}]},
      {"type":"basic","from":{"key_code":"f10"},"to":[{"key_code":"f10","modifiers":["fn"]}],"conditions":[{"type":"device_if","identifiers":[{"vendor_id":5426}]}]},
      {"type":"basic","from":{"key_code":"f11"},"to":[{"key_code":"f11","modifiers":["fn"]}],"conditions":[{"type":"device_if","identifiers":[{"vendor_id":5426}]}]},
      {"type":"basic","from":{"key_code":"f12"},"to":[{"key_code":"f12","modifiers":["fn"]}],"conditions":[{"type":"device_if","identifiers":[{"vendor_id":5426}]}]}
    ]
  }]
}
JSON
log "razer_f_keys.json written (vendor-scoped)"

cat > "$KARABINER_DIR/razer_ctrl_to_cmd.json" <<'JSON'
{
  "title": "Razer Keyboard - Control to Command",
  "rules": [{
    "description": "Map Left and Right Control to Command",
    "manipulators": [
      {"type":"basic","from":{"key_code":"left_control"}, "to":[{"key_code":"left_command"}],"conditions":[{"type":"device_if","identifiers":[{"vendor_id":5426}]}]},
      {"type":"basic","from":{"key_code":"right_control"},"to":[{"key_code":"right_command"}],"conditions":[{"type":"device_if","identifiers":[{"vendor_id":5426}]}]}
    ]
  }]
}
JSON
log "razer_ctrl_to_cmd.json written (vendor-scoped)"

# ── Inject rules directly into karabiner.json (no manual UI step needed) ──────
#
# "Enable" in Karabiner's UI just copies a rule into the selected profile's
# complex_modifications.rules array in ~/.config/karabiner/karabiner.json.
# We do that here so there is zero manual clicking. The merge runs in
# JavaScript for Automation (osascript), which ships on every macOS — no
# python3 / jq / brew dependency, so it works on a clean Mac out of the box.

step "Auto-enabling rules in karabiner.json"

KARABINER_JSON="$HOME/.config/karabiner/karabiner.json"

# Back up any existing config before touching it
if [[ -f "$KARABINER_JSON" ]]; then
  BACKUP="$KARABINER_JSON.backup.$(date +%Y%m%d%H%M%S)"
  cp "$KARABINER_JSON" "$BACKUP"
  log "Backed up existing config → $(basename "$BACKUP")"
fi

osascript -l JavaScript - <<'JXA'
ObjC.import('Foundation');

function readText(p) {
  if (!$.NSFileManager.defaultManager.fileExistsAtPath($(p))) return null;
  const s = $.NSString.stringWithContentsOfFileEncodingError($(p), $.NSUTF8StringEncoding, null);
  const str = ObjC.unwrap(s);
  return str ? str : null;
}
function writeText(p, text) {
  return $(text).writeToFileAtomicallyEncodingError($(p), true, $.NSUTF8StringEncoding, null);
}

const HOME = ObjC.unwrap($.NSProcessInfo.processInfo.environment.objectForKey('HOME'));
const path = HOME + '/.config/karabiner/karabiner.json';

// device_if condition shared by every manipulator — Razer vendor id 5426.
const RAZER = [{ type: "device_if", identifiers: [{ vendor_id: 5426 }] }];
const fkey = (n) => ({ type:"basic", from:{key_code:"f"+n}, to:[{key_code:"f"+n, modifiers:["fn"]}], conditions: RAZER });

const newRules = [
  {
    description: "Razer Keyboard F-Keys to MacBook Functions",
    manipulators: [1,2,3,4,5,6,7,8,9,10,11,12].map(fkey)
  },
  {
    description: "Map Left and Right Control to Command",
    manipulators: [
      {type:"basic", from:{key_code:"left_control"},  to:[{key_code:"left_command"}],  conditions: RAZER},
      {type:"basic", from:{key_code:"right_control"}, to:[{key_code:"right_command"}], conditions: RAZER}
    ]
  }
];

// Descriptions this installer owns (incl. legacy names) — removed before
// re-adding, so renames never leave duplicate rules behind.
const managed = new Set([
  "Razer Keyboard F-Keys to MacBook Functions",
  "Razer BlackWidow V4 F-Keys to MacBook Functions", // legacy
  "Map Left and Right Control to Command"
]);

const defaultProfile = {
  complex_modifications: { parameters: {}, rules: [] },
  devices: [],
  fn_function_keys: [],
  name: "Default profile",
  selected: true,
  simple_modifications: [],
  virtual_hid_keyboard: { keyboard_type_v2: "ansi" }
};
const defaultConfig = { global: { show_in_menu_bar: true }, profiles: [defaultProfile] };

let config = defaultConfig;
const raw = readText(path);
if (raw) {
  try { config = JSON.parse(raw); }
  catch (e) { console.log("  -> karabiner.json was malformed; replacing with defaults"); config = defaultConfig; }
}

if (!Array.isArray(config.profiles) || config.profiles.length === 0) config.profiles = [defaultProfile];
let profile = config.profiles.find(p => p.selected) || config.profiles[0];
if (!profile.complex_modifications) profile.complex_modifications = { parameters: {}, rules: [] };
if (!Array.isArray(profile.complex_modifications.rules)) profile.complex_modifications.rules = [];

// Drop any managed rule (current or legacy name), then add the fresh ones on top.
profile.complex_modifications.rules =
  profile.complex_modifications.rules.filter(r => !(r && managed.has(r.description)));
for (let i = newRules.length - 1; i >= 0; i--) profile.complex_modifications.rules.unshift(newRules[i]);

writeText(path, JSON.stringify(config, null, 4));
console.log("  -> rules injected and enabled (vendor-scoped)");
JXA
log "karabiner.json updated"

# ── hidutil: Control → Command (hardware level, permanent via LaunchAgent) ─────
#
# Scoped to the Razer keyboard with --matching {"VendorID":5426}. hidutil works
# below Karabiner: on the Razer it remaps Control→Command at the HID layer; on
# every other keyboard nothing changes.
#
# Decimal values used in the plist JSON (standard JSON does not support hex):
#   0x7000000E0 = 30064771296  Left Control  → 0x7000000E3 = 30064771299  Left Command
#   0x7000000E4 = 30064771300  Right Control → 0x7000000E7 = 30064771303  Right Command
#
# Note: hidutil applies to devices present when it runs (login). If you hot-plug
# a connection mode mid-session, Karabiner (whose device condition is live)
# still covers it — so Control→Command is never lost in any mode.

step "Installing hidutil Control→Command remap (Razer-only, permanent)"

PLIST="$HOME/Library/LaunchAgents/com.razer.hidutil.keymap.plist"
mkdir -p "$HOME/Library/LaunchAgents"

cat > "$PLIST" <<'XML'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.razer.hidutil.keymap</string>
    <key>ProgramArguments</key>
    <array>
        <string>/usr/bin/hidutil</string>
        <string>property</string>
        <string>--matching</string>
        <string>{"VendorID":5426}</string>
        <string>--set</string>
        <string>{"UserKeyMapping":[{"HIDKeyboardModifierMappingSrc":30064771296,"HIDKeyboardModifierMappingDst":30064771299},{"HIDKeyboardModifierMappingSrc":30064771300,"HIDKeyboardModifierMappingDst":30064771303}]}</string>
    </array>
    <key>RunAtLoad</key>
    <true/>
    <key>KeepAlive</key>
    <false/>
</dict>
</plist>
XML
log "LaunchAgent plist written (Razer vendor-scoped)"

launchctl unload "$PLIST" 2>/dev/null || true
if ! launchctl bootstrap "gui/$(id -u)" "$PLIST" 2>/dev/null; then
  launchctl load -w "$PLIST"
fi
log "LaunchAgent registered — re-applies on every login"

/usr/bin/hidutil property --matching "{\"VendorID\":${RAZER_VENDOR_ID_HEX}}" --set '{
  "UserKeyMapping": [
    {"HIDKeyboardModifierMappingSrc": 0x7000000E0, "HIDKeyboardModifierMappingDst": 0x7000000E3},
    {"HIDKeyboardModifierMappingSrc": 0x7000000E4, "HIDKeyboardModifierMappingDst": 0x7000000E7}
  ]
}' >/dev/null
log "hidutil remap active in current session (Razer only)"

# ── macOS keyboard preference ─────────────────────────────────────────────────

step "Configuring macOS F-key preference"

defaults write NSGlobalDomain com.apple.keyboard.fnState -bool false
log "F-keys set to media-control mode"

# ── Restart Karabiner ─────────────────────────────────────────────────────────

step "Starting Karabiner-Elements"

open -a "Karabiner-Elements"
sleep 2
log "Karabiner-Elements launched"

# ── Done ──────────────────────────────────────────────────────────────────────

printf "\n${GREEN}══════════════════════════════════════════════════${NC}\n"
printf "${GREEN}  Razer keyboard — fully installed!${NC}\n"
printf "${GREEN}══════════════════════════════════════════════════${NC}\n\n"
printf "  Scoped to Razer (vendor 0x1532) — built-in keyboard untouched.\n"
printf "  Works over 2.4GHz dongle, Bluetooth, and USB-C wired.\n\n"
printf "  F-keys (Karabiner):     enabled automatically\n"
printf "  Ctrl→Cmd (Karabiner):   enabled automatically\n"
printf "  Ctrl→Cmd (hidutil):     active now + every login\n"
printf "  F-key mode:             log out/in once to take effect\n\n"
printf "  ${YELLOW}First time on this Mac?${NC}\n"
printf "  Karabiner needs Input Monitoring permission:\n"
printf "  System Settings → Privacy & Security → Input Monitoring\n"
printf "  → toggle ON Karabiner-Elements (takes ~30 seconds to appear)\n\n"
```

---

## F-Key Reference

| F-Key | Function |
|-------|----------|
| F1 | Brightness Down |
| F2 | Brightness Up |
| F3 | Mission Control |
| F4 | Launchpad |
| F5 | Keyboard Light Down |
| F6 | Keyboard Light Up |
| F7 | Previous Track |
| F8 | Play/Pause |
| F9 | Next Track |
| F10 | Mute |
| F11 | Volume Down |
| F12 | Volume Up |

---

## Troubleshooting

### F-keys not working
1. Verify "Use F1, F2, etc. keys as standard function keys" is **OFF** (System Settings → Keyboard)
2. Restart Karabiner (Cmd+Q, reopen)
3. Log out and back in

### Karabiner rules not appearing
```bash
ls ~/.config/karabiner/assets/complex_modifications/
# Should list: razer_f_keys.json  razer_ctrl_to_cmd.json
```

### Confirm the Razer is detected (any connection mode)
```bash
hidutil list | grep -i '0x1532'
```
If nothing shows, the keyboard isn't connected on the current mode — re-pair Bluetooth, reseat the dongle, or replug the cable.

### Control key not remapping
```bash
hidutil property --matching '{"VendorID":0x1532}' --get UserKeyMapping
```
Then confirm the Karabiner "Control to Command" rule is enabled and restart Karabiner.

### hidutil remap not persisting after reboot
```bash
launchctl list | grep razer            # should show com.razer.hidutil.keymap
launchctl load -w ~/Library/LaunchAgents/com.razer.hidutil.keymap.plist
```

---

## Using a non-Razer keyboard too

Scoping is by **vendor ID**, so any Razer keyboard works automatically. To extend the
remap to a different brand, find its vendor ID:

```bash
hidutil list | grep -i keyboard   # first hex column is the vendor ID
```

Then add it to the identifiers array (Karabiner allows multiple), e.g.:

```json
"identifiers":[{"vendor_id":5426},{"vendor_id":1452}]
```

(`1452` = Apple, shown as an example.) No rewrite — just one extra entry per manipulator.

---

## Uninstall

Run the bundled uninstaller — it reverses everything `install.sh` did (removes the
LaunchAgent, clears the hidutil remap, deletes the Karabiner rule files, strips the
two rules out of `karabiner.json`, and restores the default F-key mode):

```bash
bash uninstall.sh
```

<details>
<summary>Or do it manually</summary>

```bash
# Remove hidutil LaunchAgent
launchctl unload ~/Library/LaunchAgents/com.razer.hidutil.keymap.plist
rm ~/Library/LaunchAgents/com.razer.hidutil.keymap.plist

# Clear hidutil remap immediately (Razer only)
hidutil property --matching '{"VendorID":0x1532}' --set '{"UserKeyMapping":[]}'

# Remove Karabiner rule files
rm ~/.config/karabiner/assets/complex_modifications/razer_f_keys.json
rm ~/.config/karabiner/assets/complex_modifications/razer_ctrl_to_cmd.json

# Restore default F-key mode
defaults delete NSGlobalDomain com.apple.keyboard.fnState
```

Then remove the two rules from Karabiner-Elements → Complex Modifications.

</details>

---

## License

MIT — do whatever you like.

---

**Tested on:** macOS 13 Ventura+, Razer BlackWidow V4 (works with any Razer keyboard), Karabiner-Elements
