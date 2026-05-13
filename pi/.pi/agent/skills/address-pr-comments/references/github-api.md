# GitHub API Patterns for PR Review Threads

## Fetch All Unresolved Review Threads

Returns every open thread with its ID, file location, diff hunk, and root
comment ID (needed for posting replies).

```sh
gh api graphql -f query='
  query($owner: String!, $repo: String!, $number: Int!) {
    repository(owner: $owner, name: $repo) {
      pullRequest(number: $number) {
        reviewThreads(first: 100) {
          nodes {
            id
            isResolved
            path
            line
            originalLine
            diffHunk
            comments(first: 10) {
              nodes {
                id
                databaseId
                body
                author { login }
                createdAt
              }
            }
          }
        }
      }
    }
  }
' -f owner=OWNER -f repo=REPO -F number=NUMBER
```

Filter to unresolved threads after fetching:

```sh
gh api graphql ... | jq '[.data.repository.pullRequest.reviewThreads.nodes[] | select(.isResolved == false)]'
```

## Reply to an Inline Comment Thread

Use the REST API with the **root comment's `databaseId`** (not the thread ID or
GraphQL node ID).

```sh
gh api "repos/{owner}/{repo}/pulls/{pull_number}/comments/{comment_id}/replies" \
  --method POST \
  --field body="Changes applied: ..."
```

`{owner}`, `{repo}`, and `{branch}` are auto-filled from the current repo
context. Hardcode them or set `GH_REPO=owner/repo` to target a specific repo.

## Resolve a Review Thread

Uses the thread's **GraphQL node `id`** (e.g., `PRRT_kwDO...`).

```sh
gh api graphql -f query='
  mutation($threadId: ID!) {
    resolveReviewThread(input: {threadId: $threadId}) {
      thread {
        id
        isResolved
      }
    }
  }
' -f threadId="PRRT_kwDO..."
```

## Unresolve a Review Thread

```sh
gh api graphql -f query='
  mutation($threadId: ID!) {
    unresolveReviewThread(input: {threadId: $threadId}) {
      thread {
        id
        isResolved
      }
    }
  }
' -f threadId="PRRT_kwDO..."
```

## Get PR Number from Current Branch

```sh
gh pr view --json number,headRefName,baseRefName,title
```

## Get Owner and Repo from Git Remote

```sh
gh repo view --json owner,name
```

Or parse from git:

```sh
git remote get-url origin
# e.g. https://github.com/owner/repo.git or git@github.com:owner/repo.git
```

## Post a General PR Comment (not inline)

```sh
gh pr comment <number> --body "Summary of all changes made in response to review."
```

## Check Current Review Thread Status After Changes

Re-run the fetch query and filter to confirm all threads are resolved:

```sh
gh api graphql -f query='...' | \
  jq '[.data.repository.pullRequest.reviewThreads.nodes[] | select(.isResolved == false)] | length'
# Should return 0 when all threads are resolved
```
