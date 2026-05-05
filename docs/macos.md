# macOS Configuration

This directory contains macOS-specific configurations managed via GNU Stow.

## Setup

To symlink the configurations to your home directory:

```bash
stow macos
```

## SearXNG Launch Agent

The `Library/LaunchAgents/com.peterbenjamin.searxng.plist` file configures a
background agent to run a local instance of SearXNG.

### Requirements

- **SearXNG Source**: The agent expects SearXNG to be cloned at
  `~/Projects/github.com/searxng/searxng`.
- **Virtual Environment**: A Python virtual environment must be created at
  `~/Projects/github.com/searxng/searxng/.venv`.

### Usage

1. **Install SearXNG**: Ensure you have the source code and a virtual
   environment set up at the paths specified in the `.plist` file.

2. **Load the Agent**:

   ```bash
   launchctl load ~/Library/LaunchAgents/com.peterbenjamin.searxng.plist
   ```

3. **Unload the Agent**:

   ```bash
   launchctl unload ~/Library/LaunchAgents/com.peterbenjamin.searxng.plist
   ```

4. **Check Logs**:
   - Stdout: `~/Library/Logs/searxng.out.log`
   - Stderr: `~/Library/Logs/searxng.err.log`

### Configuration

The agent runs SearXNG on `http://127.0.0.1:8888`. You can modify the port and
bind address by editing the `.plist` file before running `stow`.

> [!WARNING] The `.plist` contains hardcoded paths to the user's home directory.
> If you are deploying this to a machine with a different username or directory
> structure, update the paths in
> `macos/Library/LaunchAgents/com.peterbenjamin.searxng.plist` accordingly.
