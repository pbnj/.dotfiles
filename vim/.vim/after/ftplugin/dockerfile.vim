let &l:keywordprg = ':!ddgr docker'

call ale#linter#Define('dockerfile', {
      \ 'name': 'docker-language-server',
      \ 'lsp': 'stdio',
      \ 'executable': 'docker-langserver',
      \ 'command': '%e --stdio',
      \ 'language': 'dockerfile',
      \ 'project_root': { _ -> expand('%p:h') }
      \})
