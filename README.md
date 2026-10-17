# 🌌 Antigravity Switcher (`agy-switch`)

> Fast, secure multi-account manager and switcher for Google Antigravity CLI (`agy`).

Manage up to 5 Google accounts seamlessly with instant circular cycling, interactive fuzzy selection (`fzf`), native OS keyring security, and zero-friction cross-machine migration (Mac ⇄ Ubuntu Server).

---

## ⚡ 1-Line Quick Install

Run this in your terminal (macOS or Linux):

```bash
curl -fsSL https://raw.githubusercontent.com/NoorGuru/antigravity-switcher/main/install.sh | bash
```

Restart your terminal or run:
```bash
source ~/.config/antigravity/switcher.sh
```

---

## ✨ Features

- **🛡️ Native OS Keyring Storage**: Uses Apple Keychain on macOS and FreeDesktop Secret Service on Linux. Tokens are never stored in plaintext on disk.
- **🔄 Auto Refresh-Token Sync**: Automatically syncs Google's background OAuth refresh-token rotations back to the active slot before switching, preventing expired sessions.
- **⚡ 1-Command Account Cycling**: Rotate to the next account with `next-agy` or `nagy` (switches + launches `yagy`).
- **🔍 Interactive Fuzzy Picker**: Run `use-agy` to bring up an `fzf` menu showing all accounts and active status.
- **🖥️ Full Ubuntu Server Support**: Works flawlessly on headless Linux servers over SSH with automatic D-Bus and Secret Service initialization.
- **📦 Effortless Machine Migration**: Export all 5 accounts with `export-agy` on your Mac and load them into your Ubuntu server in seconds with `import-agy`.
- **🎯 Direct Slot Launchers**: Run `agy1`..`agy5` or `yagy1`..`yagy5` to jump straight into a specific account.

---

## 🚀 Quickstart

### 1. Save Your Accounts to Slots (1 to 5)

Log into your first Google account with `agy`, then save it:
```bash
save-agy 1
```

Log out and switch to your second account inside `agy` (`/logout` then `/login`), then save it:
```bash
save-agy 2
```
*(Repeat for up to 5 accounts)*

### 2. Check Status

See all accounts and which one is active:
```bash
status-agy
```
```text
═══════════════════════════════════════════
         Antigravity Account Status        
═══════════════════════════════════════════
Active: 🟢 Slot 1 (you@gmail.com)
-------------------------------------------
Slots:
  [1] you@gmail.com                  (active)
  [2] work@company.com
  [3] secondary@gmail.com
  [4] (empty - run 'save-agy 4')
  [5] (empty - run 'save-agy 5')
═══════════════════════════════════════════
```

### 3. Switch Accounts

- **Interactive menu (fzf):**
  ```bash
  use-agy
  ```
- **Direct slot switch:**
  ```bash
  use-agy 2
  ```
- **Cycle sequentially:**
  ```bash
  next-agy   # or n-agy
  prev-agy   # or p-agy
  ```

---

## 📋 Commands Reference

| Command | Description |
| :--- | :--- |
| `save-agy <1-5>` | Saves the current active session to a slot |
| `use-agy [1-5]` | Switches active account (opens interactive `fzf` menu if empty) |
| `status-agy` | Displays dashboard with all 5 slots and current active account |
| `next-agy` / `n-agy` | Cycles to the next saved account |
| `prev-agy` / `p-agy` | Cycles to the previous saved account |
| `nagy` | Cycles to the next account and launches `yagy` (`--dangerously-skip-permissions`) |
| `pagy` | Cycles to previous account and launches `yagy` |
| `tagy` | Alias for `nagy` |
| `agy1` .. `agy5` | Switches to slot 1–5 and launches standard `agy` |
| `yagy1` .. `yagy5` | Switches to slot 1–5 and launches `yagy` |
| `slot-agy <1-5>` | Pins the current terminal session to a specific slot |
| `unpin-agy` | Unpins current terminal (reverts to global active account) |
| `export-agy [file]` | Exports all saved slots into an encrypted/JSON backup file (chmod 600) |
| `import-agy <file>` | Imports backup file directly into the OS keyring on any machine |

---

## 👥 Running Multiple Accounts in Parallel (Multi-Terminal)

Want to run two different Google accounts simultaneously in split terminals or separate tabs without logging in and out?

`agy` loads your account's OAuth token into **process memory** upon startup. Once launched, each terminal session stays authenticated to its own account independently!

### Method 1: Direct Slot Launchers (Quickest)
Open two terminal tabs:
* **Terminal 1:** Run `yagy1` *(Starts agy using Account 1)*
* **Terminal 2:** Run `yagy2` *(Starts agy using Account 2)*

Both sessions will run simultaneously on their respective accounts and quotas without interrupting each other!

### Method 2: Shell Pinning (`slot-agy`)
If you want an entire terminal tab dedicated to a project or account:
* **Terminal 1:**
  ```bash
  slot-agy 1    # Pins this tab to Account 1
  ```
  Now every `agy`, `yagy`, or `agy -c` command in this tab will automatically execute under **Account 1**.
* **Terminal 2:**
  ```bash
  slot-agy 2    # Pins this tab to Account 2
  ```
  Any command in this tab will automatically execute under **Account 2**.

To check pin status or unpin:
```bash
slot-agy       # Check which slot this tab is pinned to
unpin-agy      # Revert to global active slot
```

---

### 🐧 Why is this even better on Ubuntu Server?
* **On macOS:** macOS has a single, system-wide Apple Keychain per user. While both terminals work in parallel in memory, the Keychain on disk reflects whichever slot was activated last.
* **On Ubuntu Linux:** Keyrings are managed via D-Bus session buses (`DBUS_SESSION_BUS_ADDRESS`). This means each terminal can have its own **physically isolated keyring daemon**—neither terminal can ever touch or overwrite the other on disk!

---

## 🖥️ Copying Accounts to an Ubuntu Server

Want to use all your saved accounts on a remote Ubuntu server without logging in 5 times?

### 1. On your Mac (Export)
```bash
export-agy ~/agy_slots_backup.json
```

### 2. Copy to your Server
```bash
scp ~/agy_slots_backup.json user@your-server-ip:~/
```

### 3. On your Ubuntu Server (Install & Import)
Install dependencies and the switcher on the server:
```bash
# Install keyring packages
sudo apt update && sudo apt install -y libsecret-tools gnome-keyring dbus-x11 python3 fzf

# Install switcher
curl -fsSL https://raw.githubusercontent.com/NoorGuru/antigravity-switcher/main/install.sh | bash
source ~/.config/antigravity/switcher.sh

# Import accounts directly
import-agy ~/agy_slots_backup.json
rm ~/agy_slots_backup.json
```

Run `status-agy` on the server — all your accounts are ready to go!

---

## 🐧 Headless Ubuntu / Linux Server Notes

On headless servers without an active desktop environment, D-Bus and `gnome-keyring-daemon` are required by Linux to store and retrieve credentials securely over SSH.

The installer automatically initializes this during installation and configures it in your `~/.bashrc` / `~/.zshrc`:
```bash
if [[ "$OSTYPE" != "darwin"* ]]; then
  [ -z "$DBUS_SESSION_BUS_ADDRESS" ] && command -v dbus-launch &>/dev/null && eval $(dbus-launch --sh-syntax 2>/dev/null)
  if command -v gnome-keyring-daemon &>/dev/null; then
    eval $(gnome-keyring-daemon --start --components=secrets 2>/dev/null)
    printf "\n" | gnome-keyring-daemon --replace --unlock 2>/dev/null || true
  fi
fi
```

---

## 🗑️ Uninstallation

To remove the switcher:
```bash
curl -fsSL https://raw.githubusercontent.com/NoorGuru/antigravity-switcher/main/uninstall.sh | bash
```
*(Your saved Keychain entries will remain safely in your OS keyring)*

---

## 📄 License

MIT © [Noor](https://github.com/NoorGuru)
