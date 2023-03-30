function fish_prompt
    set_color $fish_color_cwd
    echo
    echo (prompt_pwd)
    set_color normal
    echo '$ '
end
