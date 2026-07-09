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
container_hold_for_debug(){
    status="$1"
    mkdir -p "$TMPDIR"
    echo "$status" >"$TMPDIR/start_failed.status" 2>/dev/null
    logger "ShellCrash Docker代理模式启动失败，容器将保持运行以便排查。" 31
    logger "请使用 docker exec -it shellcrash /bin/sh 进入容器，修复配置或核心后执行 docker restart shellcrash。" 33
    while :; do
        sleep 3600 &
        wait "$!"
    done
}
start_container(){
    [ -n "$(pidof CrashCore)" ] && $0 stop
    trap 'container_shutdown; exit 0' INT TERM
    while :; do
        rm -f "$CRASHDIR"/\.start_error
        bfstart || container_hold_for_debug "$?"
        mkdir -p "$TMPDIR"
        date +%s >"$TMPDIR"/crash_start_time
        container_after_start &
        logger "ShellCrash Docker代理模式启动：代理端口 ${mix_port}/tcp+udp，面板端口 ${db_port}/tcp" 32
        $COMMAND &
        core_pid=$!
        echo "$core_pid" >"$TMPDIR/shellcrash.pid"
        wait "$core_pid"
        status=$?
        rm -f "$TMPDIR/shellcrash.pid"
        core_pid=
        [ -f "$TMPDIR/restart_core" ] || container_hold_for_debug "$status"
        rm -f "$TMPDIR/restart_core"
        logger "ShellCrash Docker代理模式正在重启内核……" 33
    done
}
start_macvlan_container(){
    [ -n "$(pidof CrashCore)" ] && $0 stop
    stop_firewall
    rm -f "$CRASHDIR"/\.start_error
    . "$CRASHDIR"/starts/fw_start.sh
    date +%s >"$TMPDIR"/crash_start_time
    container_after_start &
    trap 'stop_firewall; rm -f "$TMPDIR/shellcrash.pid"; exit 0' INT TERM
    logger "ShellCrash Docker macvlan旁路由模式启动：已配置防火墙转发" 32
    while :; do
        sleep 3600 &
        echo "$!" >"$TMPDIR/shellcrash.pid"
        wait "$!"
    done
}
stop_container(){
    container_shutdown
    rm -rf "$TMPDIR"/CrashCore
}
restart_container_core(){
    mkdir -p "$TMPDIR"
    touch "$TMPDIR/restart_core"
    container_shutdown
}

case "$1" in

start)
    require_container
    is_container_proxy && {
        [ -n "$(pidof CrashCore)" ] && [ -f "$TMPDIR/shellcrash.pid" ] && {
            restart_container_core
            exit 0
        }
        start_container
    }
    is_macvlan_mode && start_macvlan_container
    logger "不支持的 Docker 运行模式：firewall_area=$firewall_area" 31
    exit 1
    ;;
stop)
    require_container
    is_container_proxy && {
        stop_container
        exit 0
    }
    logger ShellCrash旁路由转发即将关闭……
    [ -f "$TMPDIR/shellcrash.pid" ] && kill -TERM "$(cat "$TMPDIR/shellcrash.pid")" 2>/dev/null
    rm -f "$TMPDIR/shellcrash.pid"
    stop_firewall
    killall CrashCore 2>/dev/null
    #清理缓存目录
    rm -rf "$TMPDIR"/CrashCore
    ;;
restart)
    require_container
    is_container_proxy && {
        restart_container_core
        exit 0
    }
    $0 stop
    $0 start
    ;;
init)
    require_container
    . "$CRASHDIR"/init.sh
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
    is_container_proxy || afstart
    ;;
*)
    require_container
    "$1" "$2" "$3" "$4" "$5" "$6" "$7"
    ;;

esac
