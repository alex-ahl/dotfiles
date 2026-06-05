function jjq {
    jq -R -r "${1:-.} as \$line | try fromjson catch \$line"
}
. "$HOME/.cargo/env"
