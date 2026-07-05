#!/bin/sh
set -eu

CRASHDIR="${CRASHDIR:-/etc/ShellCrash}"
DATADIR="${SHELLCRASH_DATADIR:-/data}"
export CRASHDIR

. "$CRASHDIR"/libs/docker_data.sh
init_docker_data_defaults

if [ -x "$DATADIR/CrashCore" ]; then
    cp -f "$DATADIR/CrashCore" /tmp/ShellCrash/CrashCore
    chmod 755 /tmp/ShellCrash/CrashCore
elif [ -f "$DATADIR/CrashCore.gz" ]; then
    gunzip -c "$DATADIR/CrashCore.gz" >/tmp/ShellCrash/CrashCore
    chmod 755 /tmp/ShellCrash/CrashCore
fi

cfg="$DATADIR/configs/ShellCrash.cfg"

if [ "$#" -eq 0 ]; then
    set -- start
fi

has_bootstrap_config() {
    [ -s "$DATADIR/yamls/config.yaml" ] && return 0
    [ -s "$DATADIR/jsons/config.json" ] && return 0
    (
        set +u
        . "$cfg"
        [ -n "${Url:-}" ] || [ -n "${Https:-}" ]
    )
}

wait_for_config() {
    echo "ShellCrash Docker容器已启动，但未检测到订阅或核心配置。"
    echo "请使用 docker exec -it shellcrash crash 或 docker exec -it shellcrash /bin/sh 导入配置后重启容器。"
    trap 'exit 0' INT TERM
    while :; do
        sleep 3600 &
        wait "$!"
    done
}

if [ "$1" = "start" ] || [ "$1" = "stop" ] || [ "$1" = "restart" ] || [ "$1" = "debug" ] || [ "$1" = "init" ]; then
    if [ "$1" = "start" ] && ! has_bootstrap_config; then
        wait_for_config
    fi
    exec "$CRASHDIR/start.sh" "$@"
fi

exec "$@"
