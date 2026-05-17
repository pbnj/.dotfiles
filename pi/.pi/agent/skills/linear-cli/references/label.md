# label (alias: l)

Manage Linear issue labels.

```bash
linear l list                           # Default team labels
linear l list --team ENG                # Team-specific labels
linear l list --workspace               # Workspace-level labels only
linear l list --all                     # All labels
linear l list -j

linear l create -n "priority:p0" -c "#EB5757" -t ENG
linear l create -n "shared-label"       # Workspace label (no --team)

linear l delete "bug" -t ENG
linear l delete LABEL_ID -f             # Skip confirmation
```
