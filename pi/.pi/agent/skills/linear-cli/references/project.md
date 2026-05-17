# project (alias: p)

Manage Linear projects.

## List

```bash
linear p list
linear p list --team ENG
linear p list --all-teams
linear p list --status started
linear p list -j
```

## View

```bash
linear p view PROJECT_ID
linear p view PROJECT_ID -w             # Open in browser
linear p view PROJECT_ID -a             # Open in Linear.app
```

## Create

```bash
linear p create -n "New Feature" -t ENG
linear p create \
  -n "Platform Migration" \
  -t ENG -t PLT \
  -d "Description" \
  -s planned \
  -l alice \
  --start-date 2025-06-01 \
  --target-date 2025-09-01 \
  --initiative "2025 Goals" \
  -j
```

## Update

```bash
linear p update PROJECT_ID -n "Renamed"
linear p update PROJECT_ID -s completed
linear p update PROJECT_ID --target-date 2025-12-31
linear p update PROJECT_ID -l alice --start-date 2025-07-01
```

## Delete

```bash
linear p delete PROJECT_ID
```

**Status values:** `planned`, `started`, `paused`, `completed`, `canceled`, `backlog`
