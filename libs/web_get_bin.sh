. "$CRASHDIR"/libs/web_get.sh

is_shellcrash_program_asset() {
    case "$1" in
    version|ShellCrash.tar.gz|bin/version|public/servers.list)
        return 0
        ;;
    esac
    return 1
}

allow_upstream_program_downloads() {
    [ "${SHELLCRASH_ALLOW_UPSTREAM_PROGRAM_DOWNLOADS:-}" = 1 ]
}

get_bin() { #专用于项目内部文件的下载
    if is_shellcrash_program_asset "$2" && ! allow_upstream_program_downloads; then
        [ "$3" = "echooff" ] || echo "ShellCrash程序文件下载已禁用：$2"
        return 1
    fi
    [ -z "$update_url" ] && update_url=https://testingcf.jsdelivr.net/gh/juewuy/ShellCrash@master
    if [ -n "$url_id" ]; then
		[ -n "$release_type" ] && rt="$release_type" || rt=master
        echo "$2" | grep -q '^bin/' && rt=update #/bin文件改为在update分支下载
        echo "$2" | grep -qE '^public/|^rules/' && rt=dev #/public和/rules文件改为在dev分支下载    
        server_url="$(grep "$url_id" "$CRASHDIR"/configs/servers.list 2>/dev/null | awk '{print $3}')"
        [ -z "$server_url" ] && server_url="$update_url"
        [ -z "$server_url" ] && server_url=https://testingcf.jsdelivr.net/gh/juewuy/ShellCrash
        server_url=$(echo "$server_url" | sed 's/@.*$//')
        if [ "$url_id" = 101 -o "$url_id" = 104 ]; then
            bin_url="$server_url@$rt/$2" #jsdelivr特殊处理
        else
            bin_url="$server_url/$rt/$2"
        fi
    else
        bin_url="$update_url/$2"
        echo "$2" | grep -q '^bin/' && bin_url=$(echo "$bin_url" | sed 's|@master/|@update/|; s|/master/bin/|/update/bin/|')
    fi
    webget "$1" "$bin_url" "$3" "$4" "$5" "$6"
}
