#!/bin/sh
# Copyright (C) Juewuy

#初始化目录
[ -z "$CRASHDIR" ] && CRASHDIR=$(
    cd $(dirname $0)
    pwd
)
. "$CRASHDIR"/libs/get_config.sh
#加载工具
. "$CRASHDIR"/libs/set_config.sh
. "$CRASHDIR"/libs/set_cron.sh
. "$CRASHDIR"/libs/check_cmd.sh
. "$CRASHDIR"/libs/compare.sh
. "$CRASHDIR"/libs/logger.sh
. "$CRASHDIR"/libs/web_save.sh
#特殊脚本
bfstart(){
	"$CRASHDIR"/starts/bfstart.sh
}
afstart(){
	"$CRASHDIR"/starts/afstart.sh
}
stop_firewall(){
	"$CRASHDIR"/starts/fw_stop.sh
}
is_container(){
    [ "$systype" = "container" ]
}
require_container(){
    is_container && return 0
    logger "当前版本仅支持 Docker 运行！" 31
    exit 1
}
is_macvlan_mode(){
    [ "$firewall_area" = "5" ]
}
is_container_proxy(){
    is_container && ! is_macvlan_mode
}
container_after_start(){
    sleep 2
    [ -s "$CRASHDIR"/configs/web_save ] && {
        . "$CRASHDIR"/libs/web_restore.sh
        web_restore >/dev/null 2>&1
    }
    logger ShellCrash服务已启动！
}
container_shutdown(){
    logger ShellCrash服务即将关闭……
    [ -n "$(pidof CrashCore)" ] && web_save
    if [ -n "$core_pid" ]; then
        kill -TERM "$core_pid" 2>/dev/null
    elif [ -f "$TMPDIR/shellcrash.pid" ]; then
        kill -TERM "$(cat "$TMPDIR/shellcrash.pid")" 2>/dev/null
    else
        for pid in $(pidof CrashCore 2>/dev/null); do
            kill -TERM "$pid" 2>/dev/null
        done
    fi
    rm -f "$TMPDIR/shellcrash.pid"
}
start_container(){
    [ -n "$(pidof CrashCore)" ] && $0 stop
    rm -f "$CRASHDIR"/\.start_error
    bfstart || exit 1
    mkdir -p "$TMPDIR"
    date +%s >"$TMPDIR"/crash_start_time
    container_after_start &
    trap 'container_shutdown; exit 0' INT TERM
    logger "ShellCrash Docker代理模式启动：代理端口 ${mix_port}/tcp+udp，面板端口 ${db_port}/tcp" 32
    $COMMAND &
    core_pid=$!
    echo "$core_pid" >"$TMPDIR/shellcrash.pid"
    wait "$core_pid"
    status=$?
    rm -f "$TMPDIR/shellcrash.pid"
    exit "$status"
}
stop_container(){
    container_shutdown
    rm -rf "$TMPDIR"/CrashCore
}
#保守模式启动
start_l(){
	bfstart && {
		. "$CRASHDIR"/starts/start_legacy.sh
		start_legacy "$COMMAND" 'shellcrash'	
	} && afstart &
}

case "$1" in

start)
    require_container
    is_container_proxy && start_container
    [ -n "$(pidof CrashCore)" ] && $0 stop #禁止多实例
    stop_firewall                          #清理路由策略
	rm -f "$CRASHDIR"/\.start_error #移除自启失败标记
    #使用不同方式启动服务
	if [ "$firewall_area" = "5" ]; then #主旁转发
        . "$CRASHDIR"/starts/fw_start.sh
    elif [ "$start_old" = "ON" ]; then
        start_l
    elif [ -f /etc/rc.common ] && grep -q 'procd' /proc/1/comm; then
        /etc/init.d/shellcrash start
    elif [ "$USER" = "root" ] && grep -q 'systemd' /proc/1/comm; then
		FragmentPath=$(systemctl show -p FragmentPath shellcrash | sed 's/FragmentPath=//')
		[ -f "$FragmentPath" ] && {
			sed -i "s#^ExecStart=.*#ExecStart=$COMMAND >/dev/null#" "$FragmentPath"
			systemctl daemon-reload
		}
		systemctl start shellcrash.service || . "$CRASHDIR"/starts/start_error.sh
    elif grep -q 's6' /proc/1/comm; then
		bfstart && /command/s6-svc -u /run/service/shellcrash && {
			[ ! -f "$CRASHDIR"/.dis_startup ] && touch /etc/s6-overlay/s6-rc.d/user/contents.d/afstart
			afstart &
		}
    elif rc-status -r >/dev/null 2>&1; then
        rc-service shellcrash stop >/dev/null 2>&1
        rc-service shellcrash start
    else
        start_l
    fi
    ;;
stop)
    require_container
    is_container_proxy && {
        stop_container
        exit 0
    }
    logger ShellCrash服务即将关闭……
    [ -n "$(pidof CrashCore)" ] && web_save #保存面板配置
    #清理定时任务
	cronload | grep -vE '^$|start_legacy_wd.sh|运行时每' > "$TMPDIR"/cron_tmp
	cronadd "$TMPDIR"/cron_tmp
	rm -f "$TMPDIR"/cron_tmp
    #停止tg_bot
    . "$CRASHDIR"/menus/bot_tg_service.sh && bot_tg_stop
    #多种方式结束进程
    if [ -f "$TMPDIR/shellcrash.pid" ];then
        kill -TERM "$(cat "$TMPDIR/shellcrash.pid")" 2>/dev/null
        rm -f "$TMPDIR/shellcrash.pid"
        stop_firewall
    elif [ "$USER" = "root" ] && grep -q 'systemd' /proc/1/comm; then
        systemctl stop shellcrash.service >/dev/null 2>&1
    elif [ -f /etc/rc.common ] && grep -q 'procd' /proc/1/comm; then
        /etc/init.d/shellcrash stop >/dev/null 2>&1
    elif grep -q 's6' /proc/1/comm; then
		/command/s6-svc -d /run/service/shellcrash
		stop_firewall
    elif rc-status -r >/dev/null 2>&1; then
        rc-service shellcrash stop >/dev/null 2>&1
    else
        stop_firewall
    fi
    killall CrashCore 2>/dev/null
    #清理缓存目录
    rm -rf "$TMPDIR"/CrashCore
    ;;
restart)
    require_container
    $0 stop
    $0 start
    ;;
init)
    require_container
    . "$CRASHDIR"/starts/general_init.sh
    ;;
daemon)
    require_container
    if [ -f $TMPDIR/crash_start_time ]; then
        $0 start
    else
        sleep 60 && touch $TMPDIR/crash_start_time
    fi
    ;;
debug)
    require_container
    [ -n "$(pidof CrashCore)" ] && $0 stop >/dev/null #禁止多实例
    is_container_proxy || stop_firewall >/dev/null    #清理路由策略
    bfstart
    if [ -n "$2" ]; then
        if echo "$crashcore" | grep -q 'singbox'; then
            sed -i "s/\"level\": \"info\"/\"level\": \"$2\"/" "$TMPDIR"/jsons/log.json 2>/dev/null
        else
            sed -i "s/log-level: info/log-level: $2/" "$TMPDIR"/config.yaml
        fi
        [ "$3" = flash ] && dir="$CRASHDIR" || dir="$TMPDIR"
        $COMMAND >"$dir"/debug.log 2>&1 &
        sleep 2
        logger "已运行debug模式!如需停止，请使用重启/停止服务功能！" 33
    else
        if is_container_proxy; then
            $COMMAND
            exit $?
        else
            $COMMAND >/dev/null 2>&1 &
        fi
    fi
    afstart
    ;;
*)
    require_container
    "$1" "$2" "$3" "$4" "$5" "$6" "$7"
    ;;

esac
