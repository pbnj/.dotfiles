---
name: address-pr-comments
description: "Use when addressing, responding to, or resolving pull request review comments
  and inline code suggestions. Triggers whenever the user wants to work through
  PR feedback — even if they say 'address the review comments', 'fix the PR
  feedback', 'apply the suggestions', 'resolve the threads', 'respond to
  reviewer comments', or just 'let's work through this PR review'. Use
  proactively after a PR review is received."
compatibility: "Requires gh CLI v2+ (https://cli.github.com) authenticated with `gh auth
  login`. Git must be configured for the working repository. Run `gh auth
  status` to verify before starting."
metadata:
  author: Peter Benjamin
  version: 0.1.0
allowed-tools: Bash(gh:*) Bash(git:*) Read Write
---

# Address PR Comments

A skill for systematically retrieving, addressing, and resolving pull request
review comments and inline code suggestions.

At a high level, the process is:

1. **Fetch Phase** — Retrieve all open review threads for the PR.
2. **Triage Phase** — Classify each thread by type and decide what action to
   take.
3. **Address Phase** — Make code changes to satisfy each actionable comment.
4. **Respond Phase** — Reply to each addressed thread describing what was done.
5. **Resolve Phase** — Mark each addressed thread as resolved.
6. **Commit Phase** — Commit all changes and push to the PR branch.

---

## Fetch Phase

Retrieve all unresolved review threads using the GitHub GraphQL API. See
`references/github-api.md` for the full queries.

Extract for each thread:

- Thread ID (`id`) — needed for resolving
- File path and line number — where the comment lives in the diff
- Diff hunk — the surrounding code context
- Comment body — what the reviewer wrote (may contain a suggestion block)
- Author login — who left the comment
- `isResolved` — skip threads already resolved

If no PR number is provided, infer it and the repo context from the current
branch:

```sh
gh pr view --json number,headRefName,baseRefName
gh repo view --json owner,name
```

---

## Triage Phase

Classify each open thread into one of these categories:

| Type           | Signal                                                  | Action                     |
| -------------- | ------------------------------------------------------- | -------------------------- |
| **Suggestion** | Comment body contains ` ```suggestion ` block           | Apply the diff to the file |
| **Change**     | Reviewer explicitly requests a code change              | Make the change            |
| **Nit**        | Minor style/typo, often prefixed with "nit:"            | Fix it                     |
| **Question**   | Reviewer asks for clarification, no code change implied | Reply with answer, no edit |
| **Discussion** | Conversational, no clear action required                | Reply and resolve          |
| **Praise**     | Positive feedback ("nice!", "love this")                | Reply with thanks, resolve |

When a thread's intent is ambiguous, ask the user before making changes.

---

## Address Phase

### Applying a Code Suggestion

A suggestion block looks like this in the comment body:

````markdown
```suggestion
replacement code here
```
````

To apply it:

1. Extract the replacement lines from the suggestion block.
2. Identify the file and line range from the diff hunk (the `@@` header shows
   `+<start>,<count>`).
3. Read the file and replace the target lines with the suggestion content.
4. Write the updated file.

Apply all suggestions from a single file in one pass, adjusting for line offsets
as you go. After applying, verify the file is syntactically valid if possible.

### Addressing a Change Request

1. Read the diff hunk in the thread to understand the code context.
2. Read the full file at the affected path.
3. Make the requested change — be precise, change only what was asked.
4. If the change requires updates in multiple places (e.g., renaming a
   variable), find all occurrences and update them consistently.
5. Do not make unrelated edits in the same file.

Track every file modified and which thread ID each change addresses.

---

## Respond Phase

After making a change, reply to the inline thread to document what was done.
Keep replies brief and factual — one or two sentences.

Good reply examples:

- "Fixed — extracted the constant to the top of the file."
- "Applied suggestion. Changed `foo` to `bar` as requested."
- "Done — added the missing null check."
- "Good catch — removed the redundant import."

For questions/discussions where no code change was made, reply with the
clarification or acknowledgment.

Use the GitHub REST API to post replies (see `references/github-api.md`):

```sh
gh api repos/{owner}/{repo}/pulls/{pull_number}/comments/{comment_id}/replies \
  --method POST \
  --field body="Your reply here"
```

The `comment_id` is the ID of the **first comment** in the thread (the root
comment), not the thread ID. Both are returned by the fetch query.

---

## Resolve Phase

After replying, resolve the thread using the GraphQL mutation:

```sh
gh api graphql -f query='
  mutation($threadId: ID!) {
    resolveReviewThread(input: {threadId: $threadId}) {
      thread { id isResolved }
    }
  }
' -f threadId="<THREAD_ID>"
```

Resolve threads one at a time in the order they were addressed. Only resolve
threads that have been fully addressed — do not resolve threads that are pending
user clarification or where no change was made yet.

---

## Commit Phase

Once all addressed changes are staged, commit them together:

```sh
# Stage specific changed files (preferred in automated context)
git add <file1> <file2> ...

# Or review hunks interactively if the user is present
# git add -p

# Commit with a descriptive message
git commit -m "Address PR review comments

- <one-line summary of change 1> (thread <ID or file>)
- <one-line summary of change 2>
- <one-line summary of change 3>"

# Push to the PR branch
git push
```

Use a single commit for all review changes unless the changes are logically
unrelated (e.g., a bug fix vs. a refactor from separate reviewers).

---

## Guardrails

Resolve threads only after replying — the reply is what tells the reviewer their
feedback was seen and acted on. Resolving without a reply looks like the comment
was silently dismissed.

Limit your changes strictly to what was requested. Adding unrelated improvements
alongside review fixes makes the diff harder to review and can introduce
unexpected behavior.

If two suggestions or changes conflict in the same file (e.g., both touch the
same lines), stop and ask the user how to reconcile them rather than guessing.

If a requested change is ambiguous, post a clarifying reply to the thread and
wait for the user's input before touching the code. An incorrect "fix" is worse
than asking.

If a change would break tests, types, or existing logic, flag it before
applying. Don't silently apply something broken just to close the thread.
