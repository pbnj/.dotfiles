# Common Workflow Patterns

## Start working on an issue

```bash
linear i start ENG-123          # Sets started, assigns to you, creates branch
# ... do the work ...
linear i pr                     # Create a GitHub PR linked to the issue
```

## Daily standup

```bash
linear i mine                   # Your unstarted issues
linear i mine -s started        # What you're actively working on
linear i mine --all-states      # Everything assigned to you
```

## Create an issue from a file description

```bash
linear i create -t "Improve auth" --team ENG --description-file issue.md
```

## Query for triage

```bash
linear i query --team ENG -s triage -U -j   # Unassigned triage issues as JSON
```

## Link a PR to the current branch's issue

```bash
linear i link https://github.com/org/repo/pull/42
```

## Write a commit message with issue trailer

```bash
linear i describe               # Outputs: "ENG-123: Fix login\n\nFixes: https://linear.app/..."
```

## Multi-workspace override

```bash
linear --workspace acme i mine
```
