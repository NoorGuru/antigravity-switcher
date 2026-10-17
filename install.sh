#!/usr/bin/env bash
# =============================================================================
# Antigravity Switcher (agy-switch) Installer
# https://github.com/NoorGuru/antigravity-switcher
# =============================================================================

set -e

REPO_RAW_URL="https://raw.githubusercontent.com/NoorGuru/antigravity-switcher/main"
TARGET_DIR="$HOME/.config/antigravity"
TARGET_SCRIPT="$TARGET_DIR/switcher.sh"

echo "✨ Installing Antigravity Switcher (agy-switch)..."

# 1. Ensure target directory exists
mkdir -p "$TARGET_DIR"

# 2. Install switcher.sh (from local directory if cloned, or curl from GitHub)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" 2>/dev/null && pwd)"
if [[ -f "$SCRIPT_DIR/switcher.sh" ]]; then
  echo "📦 Copying switcher.sh from local repository..."
  cp "$SCRIPT_DIR/switcher.sh" "$TARGET_SCRIPT"
else
  echo "🌐 Downloading switcher.sh from GitHub..."
  if command -v curl &>/dev/null; then
    curl -fsSL "$REPO_RAW_URL/switcher.sh" -o "$TARGET_SCRIPT"
  elif command -v wget &>/dev/null; then
    wget -qO "$TARGET_SCRIPT" "$REPO_RAW_URL/switcher.sh"
  else
    echo "❌ Error: Neither curl nor wget is installed." >&2
    exit 1
  fi
fi

chmod +x "$TARGET_SCRIPT"

# 3. Linux-specific checks (Secret Service & D-Bus)
if [[ "$OSTYPE" != "darwin"* ]]; then
  MISSING_PKGS=()
  command -v secret-tool &>/dev/null || MISSING_PKGS+=("libsecret-tools")
  command -v gnome-keyring-daemon &>/dev/null || MISSING_PKGS+=("gnome-keyring")
  command -v dbus-launch &>/dev/null || MISSING_PKGS+=("dbus-x11")
  command -v python3 &>/dev/null || MISSING_PKGS+=("python3")

  if [[ ${#MISSING_PKGS[@]} -gt 0 ]]; then
    echo ""
    echo "⚠️  Missing Linux dependencies: ${MISSING_PKGS[*]}"
    if command -v apt-get &>/dev/null; then
      echo "👉 Please run:"
      echo "   sudo apt update && sudo apt install -y ${MISSING_PKGS[*]}"
    elif command -v dnf &>/dev/null; then
      echo "👉 Please run:"
      echo "   sudo dnf install -y libsecret gnome-keyring dbus-x11 python3"
    elif command -v pacman &>/dev/null; then
      echo "👉 Please run:"
      echo "   sudo pacman -S --noconfirm libsecret gnome-keyring dbus python"
    fi
    echo ""
  fi
fi

# 4. Inject into shell configurations (~/.zshrc and ~/.bashrc)
inject_shell_rc() {
  local rc_file="$1"
  [[ ! -f "$rc_file" ]] && touch "$rc_file"

  if ! grep -q "antigravity/switcher.sh" "$rc_file" 2>/dev/null; then
    echo "🔗 Adding switcher to $rc_file..."
    cat << 'EOF' >> "$rc_file"

# Antigravity CLI Multi-Account Switcher
if [[ "$OSTYPE" != "darwin"* ]]; then
  # Headless D-Bus & Keyring setup for Linux/SSH
  [ -z "$DBUS_SESSION_BUS_ADDRESS" ] && eval $(dbus-launch --sh-syntax 2>/dev/null)
  [ -z "$GNOME_KEYRING_CONTROL" ] && eval $(echo -n "" | gnome-keyring-daemon --unlock --components=secrets 2>/dev/null)
fi
[[ -f ~/.config/antigravity/switcher.sh ]] && source ~/.config/antigravity/switcher.sh
EOF
  else
    echo "✓ Already configured in $rc_file"
  fi
}

# Detect active shell profiles
if [[ -f "$HOME/.zshrc" || "$SHELL" == *"zsh"* ]]; then
  inject_shell_rc "$HOME/.zshrc"
fi

if [[ -f "$HOME/.bashrc" || "$SHELL" == *"bash"* ]]; then
  inject_shell_rc "$HOME/.bashrc"
fi

echo ""
echo "══════════════════════════════════════════════════════════════"
echo "  🎉 Antigravity Switcher successfully installed!             "
echo "══════════════════════════════════════════════════════════════"
echo ""
echo "🚀 To get started, restart your shell or run:"
echo "   source ~/.config/antigravity/switcher.sh"
echo ""
echo "📋 Quick Commands:"
echo "   save-agy <1-5>    Save current session to a slot"
echo "   use-agy [1-5]     Switch account (opens fzf interactive menu if empty)"
echo "   status-agy        View all slots and active account"
echo "   next-agy / nagy   Cycle to next account (+ launch yagy)"
echo "   prev-agy / pagy   Cycle to previous account (+ launch yagy)"
echo "   agy1 .. agy5      Switch to slot and run agy"
echo "   yagy1 .. yagy5    Switch to slot and run yagy"
echo "   export-agy        Export slots to backup JSON file"
echo "   import-agy <file> Import slots onto another machine/server"
echo "══════════════════════════════════════════════════════════════"
