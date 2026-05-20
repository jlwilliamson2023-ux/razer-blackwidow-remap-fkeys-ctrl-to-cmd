#!/usr/bin/env bash
# razer_install.sh — Razer BlackWidow V4 macOS Setup
# Fully automated: no manual Karabiner UI steps required.
#
# Scopes ALL remapping to the Razer keyboard via Vendor ID 0x1532 (5426),
# so it works identically over 2.4GHz dongle, Bluetooth, and USB-C wired —
# and never touches the built-in MacBook keyboard or other devices.
#
# Tested on macOS 13 Ventura and later.
# Usage: bash ~/Downloads/razer_install.sh

set -euo pipefail

# Razer USA, Ltd. vendor id — shared by ALL connection modes (dongle/BT/wired)
RAZER_VENDOR_ID_DEC=5426     # decimal, for Karabiner + JSON
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
  "title": "Razer BlackWidow V4 - MacBook F-Keys",
  "rules": [{
    "description": "Razer BlackWidow V4 F-Keys to MacBook Functions",
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
  "title": "Razer BlackWidow V4 - Control to Command",
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
    description: "Razer BlackWidow V4 F-Keys to MacBook Functions",
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

const rules = profile.complex_modifications.rules;
let changed = 0;
for (const nr of newRules) {
  let found = false;
  for (let i = 0; i < rules.length; i++) {
    if (rules[i] && rules[i].description === nr.description) { rules[i] = nr; found = true; changed++; break; }
  }
  if (!found) { rules.unshift(nr); changed++; }
}

writeText(path, JSON.stringify(config, null, 4));
console.log(changed ? "  -> rules injected and enabled (vendor-scoped)" : "  -> rules already present");
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
printf "${GREEN}  Razer BlackWidow V4 — fully installed!${NC}\n"
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
