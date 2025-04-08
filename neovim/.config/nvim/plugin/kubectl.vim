if exists('g:loaded_kubectl') | finish | endif
let g:loaded_kubectl = 1

function! s:kubectl_completion(A, L, P) abort
  let l:last_part = split(a:L, ' ')[-1]
  if a:A =~# '--kubeconfig='
    let l:cluster_name = split(a:A, '=')[-1]
    return systemlist('find ~/.kube/configs -type f')->map('"--kubeconfig="..v:val')->filter('v:val =~ l:cluster_name')
  elseif a:A =~# '--namespace='
    let l:kubeconfig = matchstr(a:L, '--kubeconfig=\S\+')
    let l:cmd = printf('kubectl %s get ns -o name | cut -d/ -f2', l:kubeconfig)
    let l:namespace = split(a:A, '=')[-1]
    return systemlist(l:cmd)->map('"--namespace="..v:val')->filter('v:val =~ l:namespace')
  elseif l:last_part =~# 'get\|describe'
    let l:kubeconfig = matchstr(a:L, '--kubeconfig=\S\+')
    let l:namespace = matchstr(a:L, '--namespace=\S\+')
    if l:namespace == ' '
      let l:namespace = '-A'
    endif
    let l:cmd = printf('kubectl %s %s api-resources -o name', l:kubeconfig, l:namespace)
    return systemlist(l:cmd)->filter('v:val =~ a:A')
  else
    return [
          \ '--kubeconfig=',
          \ '--namespace=',
          \ 'annotate',
          \ 'api',
          \ 'apply',
          \ 'attach',
          \ 'auth',
          \ 'autoscale',
          \ 'certificate',
          \ 'cluster',
          \ 'completion',
          \ 'config',
          \ 'cordon',
          \ 'cp',
          \ 'create',
          \ 'debug',
          \ 'delete',
          \ 'describe',
          \ 'diff',
          \ 'drain',
          \ 'edit',
          \ 'events',
          \ 'exec',
          \ 'explain',
          \ 'expose',
          \ 'get',
          \ 'kustomize',
          \ 'label',
          \ 'logs',
          \ 'patch',
          \ 'plugin',
          \ 'port',
          \ 'proxy',
          \ 'replace',
          \ 'rollout',
          \ 'run',
          \ 'scale',
          \ 'set',
          \ 'taint',
          \ 'top',
          \ 'uncordon',
          \ 'version',
          \ 'wait',
          \ ]->filter('v:val =~ a:A')
  endif
endfunction
command! -nargs=* -complete=customlist,s:kubectl_completion Kubectl
      \ <mods> terminal kubectl <args>
