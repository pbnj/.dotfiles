# auth

Manage Linear authentication and workspace credentials.

```bash
linear auth login            # Add a workspace credential (OAuth flow)
linear auth list             # List configured workspaces
linear auth whoami           # Print current authenticated user info
linear auth token            # Print the configured API token
linear auth default [slug]   # Set the default workspace
linear auth logout [slug]    # Remove a workspace credential
linear auth migrate          # Migrate plaintext credentials to system keyring
```
