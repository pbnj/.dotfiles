setlocal formatprg=shfmt\ -sr\ -ci\ -s
compiler shellcheck

command! Shfmt
                  \ terminal ++shell ++close shfmt -sr -ci -s --write %
command! Shellcheck
                  \ terminal ++shell shellcheck %
