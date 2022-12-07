" Terradoc shows terraform provider docs
function! s:terradoc(
      \ author = 'hashicorp',
      \ provider = 'aws',
      \ refs = 'heads',
      \ version = 'main'
      \ ) abort

  let l:download_dir_prefix = '/tmp/terradoc/'.a:author
  let l:download_dir = 'terraform-provider-'.a:provider.'/'.a:version

  if !isdirectory(l:download_dir_prefix.'/'.l:download_dir)
    let l:cmd_curl = printf('curl --location --create-dirs --output "%s/%s.zip" "https://github.com/%s/terraform-provider-%s/archive/refs/%s/%s.zip"',
          \ l:download_dir_prefix,
          \ l:download_dir,
          \ a:author,
          \ a:provider,
          \ a:refs,
          \ a:version
          \ )

    let l:cmd_unzip = printf('unzip "%s/%s.zip" */docs/* -d "%s/%s"',
          \ l:download_dir_prefix,
          \ l:download_dir,
          \ l:download_dir_prefix,
          \ l:download_dir
          \ )

    echo l:cmd_curl | echom l:cmd_curl
    call system(l:cmd_curl)

    echo l:cmd_unzip | echom l:cmd_unzip
    call system(l:cmd_unzip)

    execute ':cd '.l:download_dir_prefix.'/'.l:download_dir | Rg

  else

    execute ':cd '.l:download_dir_prefix.'/'.l:download_dir | Rg

  endif
endfunction

command! -nargs=* Terradoc call s:terradoc(<f-args>)
command! TerradocClean
      \ terminal ++shell ++close find /tmp/terradoc/* -maxdepth 0 -exec rm -rf {} \;
