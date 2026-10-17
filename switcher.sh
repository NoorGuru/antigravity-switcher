# Antigravity CLI Account Switcher (Slots 1-5)
# Location: ~/.config/antigravity/switcher.sh
# Supports: Linux (secret-tool) & macOS (security) | Bash & Zsh

# -----------------------------------------------------------------------------
# OS Keyring Abstraction
# -----------------------------------------------------------------------------
_agy_is_macos() {
  [[ "$OSTYPE" == "darwin"* ]]
}

_agy_keyring_get() {
  local service="$1"
  if _agy_is_macos; then
    security find-generic-password -s "$service" -a antigravity -w 2>/dev/null
  else
    secret-tool lookup service "$service" username antigravity 2>/dev/null
  fi
}

_agy_keyring_set() {
  local service="$1"
  local token="$2"
  if _agy_is_macos; then
    security add-generic-password -U -s "$service" -a antigravity -w "$token" 2>/dev/null
  else
    printf "%s" "$token" | secret-tool store --label="$service" service "$service" username antigravity 2>/dev/null
  fi
}

_agy_keyring_del() {
  local service="$1"
  if _agy_is_macos; then
    security delete-generic-password -s "$service" -a antigravity 2>/dev/null
  else
    secret-tool clear service "$service" username antigravity 2>/dev/null
  fi
}

# -----------------------------------------------------------------------------
# Token & Cache Helpers (Python 3)
# -----------------------------------------------------------------------------
_agy_get_email() {
  local token="$1"
  [[ -z "$token" ]] && return
  python3 -c "
import sys, json, base64
raw = sys.argv[1]
if raw.startswith('go-keyring-base64:'):
  raw = raw.split(':', 1)[1]
try:
  data = json.loads(base64.b64decode(raw).decode())
  id_tok = data.get('id_token', '')
  if '.' in id_tok:
    p = id_tok.split('.')[1]
    p += '=' * ((4 - len(p) % 4) % 4)
    print(json.loads(base64.urlsafe_b64decode(p).decode()).get('email', ''))
except Exception:
  pass
" "$token" 2>/dev/null
}

_agy_update_cache() {
  local slot="$1"
  local email="$2"
  python3 -c "
import json, os
p = os.path.expanduser('~/.config/antigravity/current_account.json')
os.makedirs(os.path.dirname(p), exist_ok=True)
data = {}
if os.path.exists(p):
    try:
        with open(p, 'r') as f:
            data = json.load(f)
    except Exception:
        pass
slot_val = int('$slot') if '$slot'.isdigit() else 0
if slot_val:
    data['slot'] = slot_val
if '$email':
    data['email'] = '$email'
slots = data.setdefault('slots', {})
if slot_val and '$email':
    slots[str(slot_val)] = '$email'
with open(p, 'w') as f:
    json.dump(data, f, indent=2)
" 2>/dev/null
}

_agy_cached_email() {
  local slot="$1"
  python3 -c "
import json, os, sys
p = os.path.expanduser('~/.config/antigravity/current_account.json')
if os.path.exists(p):
    try:
        with open(p, 'r') as f:
            d = json.load(f)
            sys.stdout.write(d.get('slots', {}).get(str(sys.argv[1]), ''))
    except Exception:
        pass
" "$slot" 2>/dev/null
}

# -----------------------------------------------------------------------------
# Slot Management (Slots 1-5)
# -----------------------------------------------------------------------------

# Save current session to a slot
save-agy() {
  local slot="${1:-1}"
  if [[ ! "$slot" =~ ^[1-5]$ ]]; then
    echo "❌ Invalid slot number '$slot'. Please use a number from 1 to 5."
    return 1
  fi

  local token
  token=$(_agy_keyring_get "gemini")

  if [[ -z "$token" ]]; then
    echo "❌ No active agy session found in keyring. Launch 'agy' and log in first."
    return 1
  fi

  _agy_keyring_set "agy-slot-$slot" "$token"
  local email
  email=$(_agy_get_email "$token")
  _agy_update_cache "$slot" "$email"

  if [[ -n "$email" ]]; then
    echo "✅ Saved Slot $slot ($email)"
  else
    echo "✅ Saved current session to Slot $slot"
  fi
}

# Switch active account to a slot (interactive fzf if no argument)
use-agy() {
  if [[ -z "$1" ]]; then
    if [[ -t 0 ]] && command -v fzf &>/dev/null; then
      local current_token current_email
      current_token=$(_agy_keyring_get "gemini")
      current_email=$(_agy_get_email "$current_token")

      local menu_options=()
      local semail stok i
      for i in 1 2 3 4 5; do
        semail=$(_agy_cached_email "$i")
        if [[ -z "$semail" ]]; then
          stok=$(_agy_keyring_get "agy-slot-$i")
          [[ -n "$stok" ]] && semail=$(_agy_get_email "$stok")
        fi

        if [[ -n "$semail" ]]; then
          if [[ "$semail" == "$current_email" ]]; then
            menu_options+=("[$i] $semail  ● (active)")
          else
            menu_options+=("[$i] $semail")
          fi
        else
          menu_options+=("[$i] (empty - run 'save-agy $i')")
        fi
      done

      local choice
      choice=$(printf "%s\n" "${menu_options[@]}" | fzf --height=9 --reverse --prompt="Select Account > " --header="Antigravity CLI Account Switcher")
      [[ -z "$choice" ]] && return 0

      local target_slot
      target_slot=$(echo "$choice" | grep -o '\[[0-9]\]' | tr -d '[]')
      [[ -z "$target_slot" ]] && return 0
      if echo "$choice" | grep -q "empty"; then
        echo "❌ Slot $target_slot is empty. Run 'save-agy $target_slot' to assign it."
        return 1
      fi
      use-agy "$target_slot"
      return $?
    else
      next-agy
      return $?
    fi
  fi

  local target_slot="$1"
  local target_token
  target_token=$(_agy_keyring_get "agy-slot-$target_slot")

  if [[ -z "$target_token" ]]; then
    echo "❌ Slot $target_slot not found."
    echo "   To set it up: launch 'agy', log into Account $target_slot, then run 'save-agy $target_slot'."
    return 1
  fi

  # Auto-sync current active token back to its slot to preserve refresh token rotations
  local current_token current_email
  current_token=$(_agy_keyring_get "gemini")
  if [[ -n "$current_token" ]]; then
    current_email=$(_agy_get_email "$current_token")
    if [[ -n "$current_email" ]]; then
      local s_tok s_email s
      for s in 1 2 3 4 5; do
        s_tok=$(_agy_keyring_get "agy-slot-$s")
        if [[ -n "$s_tok" ]]; then
          s_email=$(_agy_get_email "$s_tok")
          if [[ "$current_email" == "$s_email" ]]; then
            _agy_keyring_set "agy-slot-$s" "$current_token"
            _agy_update_cache "$s" "$current_email"
            break
          fi
        fi
      done
    fi
  fi

  # Activate target slot in keyring
  if ! _agy_keyring_set "gemini" "$target_token"; then
    echo "❌ Failed to update keyring entry."
    return 1
  fi

  local active_email
  active_email=$(_agy_get_email "$target_token")
  _agy_update_cache "$target_slot" "$active_email"

  if [[ -n "$active_email" ]]; then
    echo "🚀 Switched to Slot $target_slot ($active_email)"
  else
    echo "🚀 Switched to Slot $target_slot"
  fi
}

# Circular cycling helper (dir: 1 for next, -1 for prev)
_agy_cycle() {
  local dir="${1:-1}"
  local current_token cur_email
  current_token=$(_agy_keyring_get "gemini")
  cur_email=$(_agy_get_email "$current_token")

  local populated_slots=()
  local active_slot=0
  local stok semail s

  for s in 1 2 3 4 5; do
    stok=$(_agy_keyring_get "agy-slot-$s")
    if [[ -n "$stok" ]]; then
      populated_slots+=("$s")
      semail=$(_agy_get_email "$stok")
      if [[ (-n "$cur_email" && "$cur_email" == "$semail") || ("$current_token" == "$stok") ]]; then
        active_slot="$s"
      fi
    fi
  done

  local n=${#populated_slots[@]}
  if [[ "$n" -eq 0 ]]; then
    echo "❌ No saved slots found. Save a session first using 'save-agy <1-5>'."
    return 1
  elif [[ "$n" -eq 1 ]]; then
    echo "ℹ️ Only Slot ${populated_slots[*]} is configured. Run 'save-agy <slot>' to add more accounts."
    return 0
  fi

  local target_slot
  target_slot=$(python3 -c "
import sys
slots = [int(x) for x in sys.argv[1].split(',') if x]
active = int(sys.argv[2]) if sys.argv[2].isdigit() else 0
dir_step = int(sys.argv[3])
idx = slots.index(active) if active in slots else (-1 if dir_step > 0 else 0)
next_idx = (idx + dir_step) % len(slots)
print(slots[next_idx])
" "$(IFS=,; echo "${populated_slots[*]}")" "$active_slot" "$dir")

  if [[ "$dir" -ge 0 ]]; then
    echo "▶️ Next Account: Slot ${active_slot:-?} ➔ Slot $target_slot..."
  else
    echo "◀️ Previous Account: Slot ${active_slot:-?} ➔ Slot $target_slot..."
  fi
  use-agy "$target_slot"
}

# Navigation & Cycling
next-agy() { _agy_cycle 1; }
prev-agy() { _agy_cycle -1; }
alias n-agy='next-agy'
alias p-agy='prev-agy'
alias cycle-agy='next-agy'
alias toggle-agy='next-agy'

# Status Dashboard
status-agy() {
  local current_token cur_email
  current_token=$(_agy_keyring_get "gemini")
  cur_email=$(_agy_get_email "$current_token")

  local active_slot=0
  local slot_emails=()
  local stok semail s
  for s in 1 2 3 4 5; do
    stok=$(_agy_keyring_get "agy-slot-$s")
    if [[ -n "$stok" ]]; then
      semail=$(_agy_get_email "$stok")
      slot_emails[$s]="${semail:-Saved session}"
      if [[ (-n "$cur_email" && "$cur_email" == "$semail") || ("$current_token" == "$stok") ]]; then
        active_slot="$s"
      fi
    else
      slot_emails[$s]=""
    fi
  done

  echo "═══════════════════════════════════════════"
  echo "         Antigravity Account Status        "
  echo "═══════════════════════════════════════════"

  if [[ -z "$current_token" ]]; then
    echo "Active: ⚪ Not logged in"
  elif [[ "$active_slot" -gt 0 ]]; then
    echo "Active: 🟢 Slot $active_slot (${cur_email:-authenticated})"
  else
    echo "Active: 🟡 Unsaved session (${cur_email:-unknown})"
  fi

  echo "-------------------------------------------"
  echo "Slots:"
  for s in 1 2 3 4 5; do
    semail="${slot_emails[$s]}"
    if [[ -n "$semail" ]]; then
      if [[ "$s" -eq "$active_slot" ]]; then
        printf "  [%d] %-30s (active)\n" "$s" "$semail"
      else
        printf "  [%d] %s\n" "$s" "$semail"
      fi
    else
      printf "  [%d] (empty - run 'save-agy %d')\n" "$s" "$s"
    fi
  done
  echo "═══════════════════════════════════════════"
}

# -----------------------------------------------------------------------------
# Multi-Machine Backup & Sync (Export / Import)
# -----------------------------------------------------------------------------

export-agy() {
  local outfile="${1:-$HOME/agy_slots_backup.json}"
  python3 -c "
import sys, json, subprocess, os

is_mac = sys.platform == 'darwin'
data = {'slots': {}}

for i in range(1, 6):
    if is_mac:
        cmd = ['security', 'find-generic-password', '-s', f'agy-slot-{i}', '-a', 'antigravity', '-w']
    else:
        cmd = ['secret-tool', 'lookup', 'service', f'agy-slot-{i}', 'username', 'antigravity']
    try:
        res = subprocess.run(cmd, capture_output=True, text=True)
        tok = res.stdout.strip()
        if tok and not tok.startswith('security:'):
            data['slots'][str(i)] = tok
    except Exception:
        pass

out = os.path.abspath(os.path.expanduser(sys.argv[1]))
with open(out, 'w') as f:
    json.dump(data, f, indent=2)
os.chmod(out, 0o600)
print(f'✅ Exported {len(data[\"slots\"])} account slots to {out} (chmod 600)')
print('💡 Transfer to your server via: scp ' + out + ' user@server:~/')
" "$outfile"
}

import-agy() {
  local infile="${1:-$HOME/agy_slots_backup.json}"
  if [[ ! -f "$infile" ]]; then
    echo "❌ File not found: $infile"
    return 1
  fi

  if ! _agy_is_macos; then
    if ! command -v secret-tool &>/dev/null; then
      echo "❌ 'secret-tool' is not installed. Please run:"
      echo "   sudo apt update && sudo apt install -y libsecret-tools gnome-keyring dbus-x11"
      return 1
    fi
  fi

  python3 -c "
import sys, json, subprocess, os, base64

def get_email(token):
    raw = token
    if raw.startswith('go-keyring-base64:'):
        raw = raw.split(':', 1)[1]
    try:
        d = json.loads(base64.b64decode(raw).decode())
        id_tok = d.get('id_token', '')
        if '.' in id_tok:
            p = id_tok.split('.')[1]
            p += '=' * ((4 - len(p) % 4) % 4)
            return json.loads(base64.urlsafe_b64decode(p).decode()).get('email', '')
    except Exception:
        pass
    return ''

is_mac = sys.platform == 'darwin'
try:
    with open(sys.argv[1], 'r') as f:
        data = json.load(f)
except Exception as e:
    print(f'❌ Failed to read backup JSON: {e}')
    sys.exit(1)

slots = data.get('slots', data)
count = 0
first_slot = None
cache_slots = {}

print('📦 Importing account slots...')
for slot_str, token in sorted(slots.items(), key=lambda x: int(x[0]) if x[0].isdigit() else 99):
    if not slot_str.isdigit():
        continue
    slot = int(slot_str)
    service = f'agy-slot-{slot}'
    try:
        if is_mac:
            subprocess.run(['security', 'add-generic-password', '-U', '-s', service, '-a', 'antigravity', '-w', token], check=True, stdout=subprocess.DEVNULL)
        else:
            subprocess.run(['secret-tool', 'store', f'--label={service}', 'service', service, 'username', 'antigravity'], input=token.encode(), check=True, stdout=subprocess.DEVNULL, stderr=subprocess.PIPE)
    except subprocess.CalledProcessError as e:
        err = e.stderr.decode() if e.stderr else str(e)
        print(f'❌ Failed to store Slot {slot} in keyring: {err}')
        if 'login' in err or 'Object does not exist' in err:
            print('💡 Fix: Run the following once on your server to unlock the keyring:')
            print('   eval $(gnome-keyring-daemon --start --components=secrets)')
            print('   printf \"\\n\" | gnome-keyring-daemon --replace --unlock')
        sys.exit(1)

    email = get_email(token)
    cache_slots[str(slot)] = email
    if first_slot is None:
        first_slot = (slot, token, email)
    count += 1
    print(f'  ✓ Imported Slot {slot} ({email or \"authenticated\"})')

# Set first slot as active default
if first_slot:
    f_slot, f_token, f_email = first_slot
    if is_mac:
        subprocess.run(['security', 'add-generic-password', '-U', '-s', 'gemini', '-a', 'antigravity', '-w', f_token], check=True, stdout=subprocess.DEVNULL)
    else:
        subprocess.run(['secret-tool', 'store', '--label=gemini', 'service', 'gemini', 'username', 'antigravity'], input=f_token.encode(), check=True, stdout=subprocess.DEVNULL)

    cache_path = os.path.expanduser('~/.config/antigravity/current_account.json')
    os.makedirs(os.path.dirname(cache_path), exist_ok=True)
    cdata = {'slot': f_slot, 'email': f_email, 'slots': cache_slots}
    with open(cache_path, 'w') as f:
        json.dump(cdata, f, indent=2)

print(f'\n🎉 Successfully imported {count} accounts into OS keyring! Slot {first_slot[0] if first_slot else 1} is now active.')
" "$infile"
}

# -----------------------------------------------------------------------------
# Terminal Pinning (Parallel Multi-Shell Support)
# -----------------------------------------------------------------------------
slot-agy() {
  local slot="$1"
  if [[ -z "$slot" ]]; then
    if [[ -n "$AGY_SLOT" ]]; then
      local semail=$(_agy_cached_email "$AGY_SLOT")
      echo "🔒 Current terminal is pinned to Slot $AGY_SLOT (${semail:-Account $AGY_SLOT})"
    else
      echo "🔓 Current terminal is unpinned (using global active slot)"
    fi
    return 0
  fi

  if [[ "$slot" == "0" || "$slot" == "unpin" || "$slot" == "unset" ]]; then
    unset AGY_SLOT
    echo "🔓 Terminal unpinned. Using global active slot."
    return 0
  fi

  if [[ ! "$slot" =~ ^[1-5]$ ]]; then
    echo "❌ Please provide a slot from 1 to 5, or 'unpin' to remove pin."
    return 1
  fi

  export AGY_SLOT="$slot"
  local semail=$(_agy_cached_email "$slot")
  echo "🔒 Terminal pinned to Slot $slot (${semail:-Account $slot})"
  echo "   All 'agy' and 'yagy' commands in this tab will automatically use Slot $slot."
}
unpin-agy() { slot-agy unpin; }
pin-agy() { slot-agy "$@"; }

# -----------------------------------------------------------------------------
# Quick Launch Wrappers & Aliases
# -----------------------------------------------------------------------------
agy() {
  if [[ -n "$AGY_SLOT" ]]; then
    use-agy "$AGY_SLOT" >/dev/null 2>&1
  fi
  command agy "$@"
}

yagy() {
  if [[ -n "$AGY_SLOT" ]]; then
    use-agy "$AGY_SLOT" >/dev/null 2>&1
  fi
  command agy --dangerously-skip-permissions "$@"
}

nagy() { next-agy && yagy "$@"; }
pagy() { prev-agy && yagy "$@"; }
nagyn() { next-agy && agy "$@"; }
pagyn() { prev-agy && agy "$@"; }

# Direct slot commands: agy1..agy5 & yagy1..yagy5
for s in 1 2 3 4 5; do
  eval "agy$s()  { use-agy $s && command agy \"\$@\"; }"
  eval "yagy$s() { use-agy $s && command agy --dangerously-skip-permissions \"\$@\"; }"
done

alias tagy='nagy'
alias nagyc='nagy -c'
alias pagyc='pagy -c'
alias tagyc='tagy -c'
alias yagyc='yagy -c'
alias sw-agy='use-agy'
