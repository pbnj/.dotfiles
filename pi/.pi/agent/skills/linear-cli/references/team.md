# team (alias: t)

Manage Linear teams.

```bash
linear t list
linear t id                             # Print configured team ID
linear t members [teamKey]
linear t create -n "Platform" -k PLT -d "Platform team" --private
linear t delete TEAM_KEY
linear t autolinks                      # Configure GitHub autolinks for team prefix
```

## team create flags

| Flag                | Description                                   |
| ------------------- | --------------------------------------------- |
| `-n, --name`        | Team name (required)                          |
| `-k, --key`         | Team key; generated from name if not provided |
| `-d, --description` | Team description                              |
| `--private`         | Make the team private                         |
| `--no-interactive`  | Disable interactive prompts                   |
