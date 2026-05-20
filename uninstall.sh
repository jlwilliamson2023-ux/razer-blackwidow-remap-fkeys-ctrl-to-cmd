#!/usr/bin/env bash
# uninstall.sh — Razer BlackWidow V4 macOS Setup (full removal)
#
# Reverses everything install.sh did:
#   - removes + unloads the hidutil LaunchAgent and clears the Razer remap
#   - deletes the two Karabiner rule files
#   - removes the two rules from karabiner.json (by description)
#   - restores the default macOS F-key behaviour
#
# Uses only tools built into macOS. Usage: bash uninstall.sh

# Color codes are intentionally embedded in printf format strings below.
# shellcheck disable=SC2059

set -euo pipefail

RAZER_VENDOR_ID_HEX=0x1532

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'; NC='\033[0m'
log()  { printf "${GREEN}✓${NC}  %s\n" "$1"; }
warn() { printf "${YELLOW}⚠${NC}  %s\n" "$1"; }
step() { printf "\n${BLUE}▶${NC}  %s\n" "$1"; }

[[ "$(uname)" == "Darwin" ]] || { printf "${RED}✗${NC}  macOS only.\n" >&2; exit 1; }

# ── hidutil LaunchAgent ────────────────────────────────────────────────────────

step "Removing hidutil LaunchAgent + clearing remap"

PLIST="$HOME/Library/LaunchAgents/com.razer.hidutil.keymap.plist"
if [[ -f "$PLIST" ]]; then
  launchctl bootout "gui/$(id -u)" "$PLIST" 2>/dev/null || launchctl unload "$PLIST" 2>/dev/null || true
  rm -f "$PLIST"
  log "LaunchAgent removed"
else
  warn "LaunchAgent not present (already removed)"
fi

# Clear the Razer key mapping for the current session
/usr/bin/hidutil property --matching "{\"VendorID\":${RAZER_VENDOR_ID_HEX}}" \
  --set '{"UserKeyMapping":[]}' >/dev/null 2>&1 || true
log "hidutil Razer remap cleared"

# ── Karabiner rule files ───────────────────────────────────────────────────────

step "Removing Karabiner rule files"

KARABINER_DIR="$HOME/.config/karabiner/assets/complex_modifications"
rm -f "$KARABINER_DIR/razer_f_keys.json" "$KARABINER_DIR/razer_ctrl_to_cmd.json"
log "Rule files removed"

# ── Remove the rules from karabiner.json ───────────────────────────────────────

step "Removing rules from karabiner.json"

KARABINER_JSON="$HOME/.config/karabiner/karabiner.json"
if [[ -f "$KARABINER_JSON" ]]; then
  cp "$KARABINER_JSON" "$KARABINER_JSON.backup.$(date +%Y%m%d%H%M%S)"

  osascript -l JavaScript - <<'JXA'
ObjC.import('Foundation');
function readText(p){ if(!$.NSFileManager.defaultManager.fileExistsAtPath($(p))) return null;
  const s=$.NSString.stringWithContentsOfFileEncodingError($(p),$.NSUTF8StringEncoding,null);
  const str=ObjC.unwrap(s); return str?str:null; }
function writeText(p,t){ return $(t).writeToFileAtomicallyEncodingError($(p),true,$.NSUTF8StringEncoding,null); }

const HOME = ObjC.unwrap($.NSProcessInfo.processInfo.environment.objectForKey('HOME'));
const path = HOME + '/.config/karabiner/karabiner.json';
const targets = new Set([
  "Razer BlackWidow V4 F-Keys to MacBook Functions",
  "Map Left and Right Control to Command"
]);

const raw = readText(path);
if (!raw) { console.log("  -> nothing to do"); }
else {
  let config;
  try { config = JSON.parse(raw); } catch (e) { console.log("  -> malformed json, skipping"); config = null; }
  if (config && Array.isArray(config.profiles)) {
    let removed = 0;
    for (const profile of config.profiles) {
      const cm = profile.complex_modifications;
      if (cm && Array.isArray(cm.rules)) {
        const before = cm.rules.length;
        cm.rules = cm.rules.filter(r => !(r && targets.has(r.description)));
        removed += before - cm.rules.length;
      }
    }
    writeText(path, JSON.stringify(config, null, 4));
    console.log("  -> removed " + removed + " rule(s)");
  }
}
JXA
  log "karabiner.json cleaned"
else
  warn "karabiner.json not present"
fi

# ── Restore macOS F-key behaviour ──────────────────────────────────────────────

step "Restoring default F-key behaviour"

defaults delete NSGlobalDomain com.apple.keyboard.fnState 2>/dev/null || true
log "F-key preference reset to system default"

# ── Restart Karabiner so it reloads ────────────────────────────────────────────

step "Reloading Karabiner-Elements"

pkill -x "Karabiner-Elements" 2>/dev/null || true
sleep 1
open -a "Karabiner-Elements" 2>/dev/null || true
log "Karabiner reloaded"

printf "\n${GREEN}══════════════════════════════════════════════════${NC}\n"
printf "${GREEN}  Uninstall complete — all remapping removed.${NC}\n"
printf "${GREEN}══════════════════════════════════════════════════${NC}\n\n"
printf "  Log out / back in to fully reset the F-key mode.\n"
printf "  Karabiner config backups (if any) are kept next to karabiner.json.\n\n"
