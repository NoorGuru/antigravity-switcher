#!/usr/bin/env bash
# =============================================================================
# Antigravity Switcher Uninstaller
# =============================================================================

echo "🗑️  Uninstalling Antigravity Switcher..."

TARGET_SCRIPT="$HOME/.config/antigravity/switcher.sh"

if [[ -f "$TARGET_SCRIPT" ]]; then
  rm -f "$TARGET_SCRIPT"
  echo "✓ Removed $TARGET_SCRIPT"
fi

clean_shell_rc() {
  local rc="$1"
  if [[ -f "$rc" ]]; then
    # Remove the loader block
    if grep -q "antigravity/switcher" "$rc"; then
      # Make backup
      cp "$rc" "${rc}.bak_agyswitch"
      # Clean out antigravity switcher lines
      sed -i.tmp '/# Antigravity CLI Multi-Account Switcher/,/switcher.sh/d' "$rc" 2>/dev/null || \
      sed -i '' '/# Antigravity CLI Multi-Account Switcher/,/switcher.sh/d' "$rc" 2>/dev/null || true
      rm -f "${rc}.tmp"
      echo "✓ Cleaned switcher entries from $rc (backup saved to ${rc}.bak_agyswitch)"
    fi
  fi
}

clean_shell_rc "$HOME/.zshrc"
clean_shell_rc "$HOME/.bashrc"

echo "✅ Antigravity Switcher has been uninstalled. Your saved Keychain/keyring slots were preserved."
