# GitHub Follower Manager

A powerful Bash script to manage your GitHub followers and following. Easily identify users who don't follow you back, bulk unfollow non-followers, and follow back your followers - all with dry-run support and rate limiting.

![Bash](https://img.shields.io/badge/Bash-5.0%2B-green)
![Platform](https://img.shields.io/badge/Platform-Windows%20%7C%20macOS%20%7C%20Linux-blue)
![License](https://img.shields.io/badge/License-MIT-yellow)

## 🎯 Features

- **View Non-Followers**: See who you follow that doesn't follow you back
- **View Unfollowed**: See followers you haven't followed back
- **Bulk Unfollow**: Remove all non-followers at once
- **Selective Unfollow**: Review and choose each user individually
- **Bulk Follow Back**: Follow all your followers with one command
- **Dry Run Mode**: Preview actions before executing them
- **Rate Limiting**: Built-in delays to avoid GitHub API throttling
- **Progress Tracking**: Real-time progress indicators
- **Token Persistence**: Save your token securely for future sessions
- **Logging**: All actions logged with timestamps
- **Cross-Platform**: Works on Windows (Git Bash), macOS, and Linux
- **Auto-Install Dependencies**: Automatic jq installation on Windows via Scoop
- **Command-Line Arguments**: Direct option execution and auto-confirm support
- **Auto-Sync Mode**: Combine unfollow + follow operations in one command
- **Full Automation**: -y flag for completely unattended execution

## 📋 Requirements

### Dependencies

| Dependency | Purpose | Installation |
|------------|---------|--------------|
| **Bash** | Shell interpreter | Pre-installed on macOS/Linux, use Git Bash on Windows |
| **curl** | API requests | Pre-installed on most systems |
| **jq** | JSON parsing | See installation below |

### Installing jq

**Windows (Git Bash):**
```bash
# The script will offer to install automatically via Scoop
# Or manually:
scoop install jq
```

**macOS:**
```bash
brew install jq
```

**Linux (Debian/Ubuntu):**
```bash
sudo apt install jq
```

**Linux (Fedora/RHEL):**
```bash
sudo dnf install jq
```

## 🚀 Installation

1. **Clone the repository:**
   ```bash
   git clone https://github.com/lancedesk/github-unfollower.git
   cd github-unfollower
   ```

2. **Make the script executable:**
   ```bash
   chmod +x gh-followers.sh
   ```

3. **Create a GitHub Personal Access Token:**
   - Go to [GitHub Settings → Tokens](https://github.com/settings/tokens)
   - Click "Generate new token (classic)"
   - Select the `user:follow` scope
   - Copy the generated token

4. **Run the script:**
   ```bash
   ./gh-followers.sh
   ```

5. **(Optional) Install globally:**
   ```bash
   chmod +x install.sh
   ./install.sh
   ```
   Then restart your terminal and just type:
   ```bash
   followers
   ```

## 🌐 Global Installation

The `install.sh` script adds the `followers` command to your system PATH, allowing you to run it from any directory.

### Installing

```bash
chmod +x install.sh
./install.sh
```

After installation, **restart your terminal** (or run `source ~/.bashrc`) and use:

```bash
followers
```

### What the installer does

| Operating System | Installation Location | Method |
|------------------|----------------------|--------|
| **Windows (Git Bash)** | `~/bin/followers` | Wrapper script + adds to `~/.bashrc` |
| **macOS** | `/usr/local/bin/followers` or `~/bin` | Symlink |
| **Linux** | `/usr/local/bin/followers` or `~/.local/bin` | Symlink + adds to `~/.bashrc` |

### Uninstalling

To remove the `followers` command from your PATH:

```bash
chmod +x uninstall.sh
./uninstall.sh
```

This removes the command but keeps your token and logs intact.

### Files after installation

```
github-unfollower/
├── gh-followers.sh          # Main script (don't move/delete!)
├── install.sh               # Installer
├── uninstall.sh             # Uninstaller
├── .github-token            # Your saved token (gitignored)
├── .gitignore               # Ignores sensitive files
├── gh-follower-manager.log  # Action log
└── README.md                # This file
```

> **Note:** Don't move or delete the `gh-followers.sh` script after installation - the `followers` command points to it!

## 📖 Usage

### Running the Script

**Interactive Mode (default):**
```bash
./gh-followers.sh
# or with global installation:
followers
```

**Direct Command Mode:**
```bash
# Run specific option directly
./gh-followers.sh 9          # Run auto-sync (will ask about dry-run)
followers 3                   # Run bulk unfollow (will ask about dry-run)

# Auto-accept ALL prompts with -y flag (no token confirmation, no dry-run)
./gh-followers.sh 9 -y       # Auto-sync completely unattended
followers 3 -y                # Bulk unfollow completely unattended

# Arguments work in any order
followers -y 1                # Show non-followers, auto-confirm token
followers 0                   # Exit (same as using 0 in interactive mode)
```

**Command-Line Options:**
| Flag | Description |
|------|-------------|
| `-y, --yes` | Auto-accept all prompts (skip token confirmation AND dry-run prompts) |
| `-h, --help` | Show help message with all available options |

On first run, you'll be prompted to enter your GitHub token. The token is saved securely to `.github-token` for future sessions.

### Menu Options

```
=========================================
    GitHub Follower Manager
=========================================
1) Show who you follow but they don't follow back
2) Show your followers you don't follow back
3) Unfollow users who don't follow you back (bulk)
4) Unfollow users (selective - choose each)
5) Follow back your followers (bulk)
6) Show rate limit status
7) Change GitHub token
8) Debug: Show counts
9) Auto-sync: Unfollow non-followers + Follow back
0) Exit
=========================================
```

### Option Details

| Option | Description |
|--------|-------------|
| **1** | Lists users you follow who don't follow you back (potential bots/spam accounts) |
| **2** | Lists your followers that you haven't followed back yet |
| **3** | Bulk unfollow all non-followers (with dry-run option) |
| **4** | Review each non-follower individually and choose to unfollow or keep |
| **5** | Bulk follow all your followers you're not currently following |
| **6** | Check your GitHub API rate limit status |
| **7** | Update or change your GitHub token |
| **8** | Debug mode showing raw counts and mutual follow statistics |
| **9** | **Auto-sync mode**: Automatically unfollow non-followers then follow back all followers in one operation |
| **0** | Exit the program |

### Dry Run Mode

When performing bulk actions (options 3, 5, and 9), you'll be asked:
```
Dry run first? (y/n):
```

- **y**: Preview what would happen without making changes
- **n**: Execute actions immediately

**Skip with -y flag:** Use `followers 9 -y` to bypass all prompts and execute immediately (perfect for automation).

After a dry run, you can choose to execute for real:
```
Execute for real? (y/n):
```

## ⚙️ Configuration

### Automation Examples

**Linux/macOS (Cron):**
```bash
# Edit crontab
crontab -e

# Add this line for daily auto-sync at 2 AM
0 2 * * * followers 9 -y

# Optional: Redirect output for debugging
# 0 2 * * * followers 9 -y >> ~/followers-output.log 2>&1
```

> **Note:** The script already logs to `gh-follower-manager.log`. Output redirection is optional for debugging.

**Windows (Task Scheduler):**
1. Open **Task Scheduler** (search in Start menu)
2. Click **Create Basic Task**
3. Name: "GitHub Auto-Sync"
4. Trigger: **Daily** at 2:00 AM
5. Action: **Start a program**
   - Program: `C:\Program Files\Git\bin\bash.exe`
   - Arguments (choose one):
     - **Basic:** `-c "followers 9 -y"`
     - **With console output:** `-c "followers 9 -y >> ~/followers-output.log 2>&1"`
6. Finish and test

> **Note:** The script already logs actions to `gh-follower-manager.log`. The console output option is only for debugging Task Scheduler runs.

**Or use PowerShell to create the task:**
```powershell
$action = New-ScheduledTaskAction -Execute "C:\Program Files\Git\bin\bash.exe" -Argument '-c "followers 9 -y"'
$trigger = New-ScheduledTaskTrigger -Daily -At 2am
Register-ScheduledTask -Action $action -Trigger $trigger -TaskName "GitHub Auto-Sync" -Description "Daily GitHub follower auto-sync"
```

### Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `GITHUB_TOKEN` | - | Your GitHub Personal Access Token |
| `WAIT_BETWEEN_REQUESTS` | 2 | Seconds between API calls |
| `WAIT_BETWEEN_ACTIONS` | 5 | Seconds between follow/unfollow actions |

### Files Created

| File | Description |
|------|-------------|
| `.github-token` | Stores your GitHub token (gitignored) |
| `gh-follower-manager.log` | Action log with timestamps |

## 🔒 Security

- Your token is stored locally in `.github-token` with restricted permissions (`chmod 600`)
- The token file is included in `.gitignore` to prevent accidental commits
- **Never share your GitHub token or commit it to version control**

## 🐛 Troubleshooting

### Common Issues

**Script exits unexpectedly during dry run:**
- Fixed in latest version. Was caused by bash arithmetic with `set -e`

**Same users appearing in both "don't follow back" lists:**
- Fixed in latest version. Was caused by Windows line endings (`\r`)

**"jq: command not found":**
- Install jq using the commands in the Requirements section
- On Windows, the script offers automatic installation via Scoop

**"Authentication failed":**
- Ensure your token has the `user:follow` scope
- Generate a new token if the old one expired
- Use option 7 to update your token

**Rate limit exceeded:**
- Use option 6 to check your rate limit status
- Wait for the rate limit to reset (shown in the output)
- The script includes built-in delays to avoid this

### Windows-Specific Notes

- Use **Git Bash** to run the script (comes with Git for Windows)
- The script automatically detects Windows and handles line endings
- If Scoop/jq installation fails, restart your terminal after installation

### Linux/macOS Notes

- The script should work out of the box
- Ensure `bash`, `curl`, and `jq` are installed
- Make the script executable with `chmod +x gh-followers.sh`

## 📊 Rate Limits

GitHub API has rate limits:
- **Authenticated requests**: 5,000 per hour
- The script shows remaining requests after authentication
- Built-in delays prevent hitting rate limits during normal use

## 🤝 Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/AmazingFeature`)
3. Commit your changes (`git commit -m 'Add some AmazingFeature'`)
4. Push to the branch (`git push origin feature/AmazingFeature`)
5. Open a Pull Request

## 📝 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🙏 Acknowledgments

- GitHub API documentation
- The jq project for JSON parsing
- Scoop package manager for Windows

## 📧 Support

If you encounter any issues or have questions:
1. Check the Troubleshooting section above
2. Open an issue on GitHub
3. Include your OS, bash version, and error messages

---

**⚠️ Disclaimer**: Use this tool responsibly. Mass following/unfollowing may violate GitHub's Terms of Service if abused. This tool is intended for managing legitimate follower relationships.
