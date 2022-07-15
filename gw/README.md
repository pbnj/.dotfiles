# gw

> **G**rep **W**rapper

## Overview

A thin wrapper around `grep` to simplify common/repetitive scenarios.

This:

```sh
grep -oE 'https?://[^[:space:]']+' file.log
```

Becomes:

```sh
gw url file.log
```

Tab completion implemented in [.functions](https://github.com/pbnj/dotfiles/blob/9632c5c5a5938d61d30abd1b7d7e4694fff1ef9f/bash/.functions#L52-L58)

Also, supports receiving data from stdin.

See examples:

- Open URLs from tmux buffer: [`open-url`](https://github.com/pbnj/dotfiles/blob/main/utils/bin/open-url)
- Open URLs via tmux shortcut: [`.tmux.conf`](https://github.com/pbnj/dotfiles/blob/b1363b042e9fa1aa9ea36a341da088a6d696a20d/tmux/.tmux.conf#L35-L36)

## License

MIT
