if exists('g:loaded_c7n') | finish | endif
let g:loaded_c7n = 1

command! -nargs=1 -complete=file_in_path C7nRun
      \ terminal custodian run --output-dir /tmp/ --region us-west-1 --region us-west-2 --region us-east-1 --region us-east-2 --verbose <args>

command! -nargs=1 -complete=file_in_path C7nReport
      \ terminal custodian report --output-dir /tmp/ --region us-west-2 --region us-west-2 --region us-east-1 --region us-east-2 --field Nest=tag:Nest --field Owner=tag:Owner <args>
