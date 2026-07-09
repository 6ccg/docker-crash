

[ -n "$(find --help 2>&1 | grep -o size)" ] && find_para=' -size +2000'             #find命令兼容

core_unzip() { #$1:需要解压的文件 $2:目标文件名
	if echo "$1" |grep -q 'tar.gz$' ;then
		[ "$BINDIR" = "$TMPDIR" ] && rm -rf "$TMPDIR"/CrashCore #小闪存模式防止空间不足
		[ -n "$(tar --help 2>&1 | grep -o 'no-same-owner')" ] && tar_para='--no-same-owner' #tar命令兼容
		rm -rf "$TMPDIR"/core_tmp
		mkdir -p "$TMPDIR"/core_tmp
		tar -zxf "$1" ${tar_para} -C "$TMPDIR"/core_tmp/ || {
			rm -rf "$TMPDIR"/core_tmp
			return 1
		}
		for file in $(find "$TMPDIR"/core_tmp $find_para 2>/dev/null); do
			[ -f "$file" ] && [ -n "$(echo $file | sed 's#.*/##' | grep -iE '(CrashCore|sing|meta|mihomo|clash|pre)')" ] && mv -f "$file" "$TMPDIR"/"$2"
		done
		rm -rf "$TMPDIR"/core_tmp
	elif echo "$1" |grep -q '.gz$' ;then
		gunzip -c "$1" > "$TMPDIR"/"$2" || return 1
	elif echo "$1" |grep -q '.upx$' ;then
		ln -sf "$1" "$TMPDIR"/"$2"
	else
		mv -f "$1" "$TMPDIR"/"$2"
	fi
	[ -f "$TMPDIR"/"$2" ] || return 1
	chmod +x "$TMPDIR"/"$2"
}
core_find(){
	if [ ! -f "$TMPDIR"/CrashCore ];then
		[ -n "$(find "$CRASHDIR"/CrashCore.* $find_para 2>/dev/null)" ] && [ "$CRASHDIR" != "$BINDIR" ] &&
			mv -f "$CRASHDIR"/CrashCore.* "$BINDIR"/
		for ext in tar.gz gz upx; do
			core_dir=$(find "$BINDIR"/CrashCore."$ext" $find_para 2>/dev/null | head -n 1)
			[ -n "$core_dir" ] && break
		done
		[ -n "$core_dir" ] && core_unzip "$core_dir" CrashCore
	fi
}
core_check(){
	container_core_running=
	if [ -n "$(pidof CrashCore)" ]; then
		if [ "$systype" = 'container' ]; then
			container_core_running=1
		else
			"$CRASHDIR"/start.sh stop #停止内核服务防止内存不足
		fi
	fi
	core_unzip "$1" core_new || {
		rm -rf "$1" "$TMPDIR"/core_new "$TMPDIR"/core_tmp
		return 2
	}
	sbcheck=$(echo "$crashcore" | grep 'singbox')
	v=''
	if [ -n "$sbcheck" ] && "$TMPDIR"/core_new -h 2>&1 | grep -q 'sing-box'; then
		v=$("$TMPDIR"/core_new version 2>/dev/null | grep version | awk '{print $3}')
		COMMAND='"$TMPDIR/CrashCore run -D $BINDIR -C $TMPDIR/jsons"'
	elif [ -z "$sbcheck" ] && "$TMPDIR"/core_new -h 2>&1 | grep -q '\-t';then
		v=$("$TMPDIR"/core_new -v 2>/dev/null | head -n 1 | sed 's/ linux.*//;s/.* //')
		COMMAND='"$TMPDIR/CrashCore -d $BINDIR -f $TMPDIR/config.yaml"'
	fi
	if [ -z "$v" ]; then
		rm -rf "$1" "$TMPDIR"/core_new
		return 2
	else
		rm -f "$BINDIR"/CrashCore.tar.gz "$BINDIR"/CrashCore.gz "$BINDIR"/CrashCore.upx
		if [ -z "$zip_type" ];then
			gzip -c "$TMPDIR/core_new" > "$BINDIR/CrashCore.gz"
		else
			mv -f "$1" "$BINDIR/CrashCore.$zip_type"
		fi
		if [ "$container_core_running" = 1 ]; then
			cp -f "$TMPDIR/core_new" "$BINDIR/CrashCore" 2>/dev/null || {
				rm -f "$TMPDIR"/core_new
				return 2
			}
			rm -f "$TMPDIR"/core_new
		elif [ "$zip_type" = 'upx' ];then
			rm -f "$1" "$TMPDIR"/core_new
			ln -sf "$TMPDIR/CrashCore.upx" "$TMPDIR/CrashCore"
		else
			mv -f "$TMPDIR/core_new" "$TMPDIR/CrashCore"
		fi
		[ "$systype" = 'container' ] && [ "$container_core_running" != 1 ] && cp -f "$TMPDIR/CrashCore" "$BINDIR/CrashCore" 2>/dev/null
		core_v="$v"
		setconfig COMMAND "$COMMAND" "$CRASHDIR"/configs/command.env && . "$CRASHDIR"/configs/command.env
		setconfig crashcore "$crashcore"
		setconfig core_v "$core_v"
		setconfig custcorelink "$custcorelink"
		[ "$container_core_running" = 1 ] && echo -e "\033[33mDocker容器内核文件已更新，重启容器后生效！\033[0m"
		return 0
	fi
}
core_webget(){
	. "$CRASHDIR"/libs/web_get_bin.sh
	. "$CRASHDIR"/libs/check_target.sh
	if [ -z "$custcorelink" ];then
		if [ "$crashcore" = meta ]; then
			[ -n "$(echo $cpucore | grep mips)" ] && cpu_type=mips || cpu_type=$cpucore
			webget "$TMPDIR"/mihomo_release.json https://api.github.com/repos/MetaCubeX/mihomo/releases/latest echooff
			if [ "$?" = 0 ]; then
				if [ "$cpu_type" = amd64 ]; then
					custcorelink=$(grep "browser_download_url" "$TMPDIR"/mihomo_release.json | grep -E "linux-${cpu_type}-compatible.*\.gz" | head -n 1 | sed 's/.*"browser_download_url": "//;s/".*//')
				fi
				[ -z "$custcorelink" ] && custcorelink=$(grep "browser_download_url" "$TMPDIR"/mihomo_release.json | grep -E "linux-${cpu_type}.*\.gz" | head -n 1 | sed 's/.*"browser_download_url": "//;s/".*//')
			fi
			rm -f "$TMPDIR"/mihomo_release.json
			[ -z "$custcorelink" ] && return 1
		fi
	fi
	if [ -z "$custcorelink" ];then
		[ -z "$zip_type" ] && zip_type='tar.gz'
		[ "$systype" = 'container' ] && [ "$zip_type" = 'upx' ] && zip_type='tar.gz'
		get_bin "$TMPDIR/Coretmp.$zip_type" "bin/$crashcore/${target}-linux-${cpucore}.$zip_type"
	else
		case "$custcorelink" in
			*.tar.gz) zip_type="tar.gz" ;;
			*.gz)     zip_type="gz" ;;
			*.upx)    zip_type="upx" ;;
		esac
		[ -n "$zip_type" ] && webget "$TMPDIR/Coretmp.$zip_type" "$custcorelink"
	fi
	#校验内核
	if [ "$?" = 0 ];then
		core_check "$TMPDIR/Coretmp.$zip_type"
	else
		rm -f "$TMPDIR/Coretmp.$zip_type"
		return 1
	fi
}
