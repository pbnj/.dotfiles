# Pi-specific instructions

## Where my repos live

- All GitHub repos are cloned at `~/Projects/github.com/<owner>/<repo>` (e.g.
  `~/Projects/github.com/pbnj/.dotfiles`).
- Before cloning, check whether the repo already exists there. If it does, use
  that clone: fetch the latest changes and work from it rather than cloning
  again.
- If it isn't there, clone it into that path
  (`git clone <owner>/<repo> ~/Projects/github.com/<owner>/<repo>`). Never clone
  into the current directory, `/tmp` or anywhere else.
- When I name a repo without an owner, look for it under
  `~/Projects/github.com/*/` first.

## Worktrees

- Create every git worktree under `.worktrees/` at the repo's root (e.g.
  `~/Projects/github.com/pbnj/.dotfiles/.worktrees/<name>`), and do branch work
  there rather than in the main checkout. Never put worktrees in a sibling
  directory, `/tmp` or anywhere else. `.worktrees/` is ignored by my global
  gitignore.
