#!/bin/sh
set -eu

CRASHDIR="${CRASHDIR:-/etc/ShellCrash}"
DATADIR="${SHELLCRASH_DATADIR:-/data}"
export CRASHDIR

. "$CRASHDIR"/libs/docker_data.sh
init_docker_data_defaults

if [ -f "$DATADIR/CrashCore.tar.gz" ]; then
    :
elif [ -x "$DATADIR/CrashCore" ]; then
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

wait_after_start_failure() {
    status="$1"
    echo "ShellCrash启动失败，容器将保持运行以便排查。"
    echo "请使用 docker exec -it shellcrash /bin/sh 进入容器，检查 /tmp/ShellCrash/error.yaml 或 /tmp/ShellCrash/core_test.log。"
    echo "修复配置或核心后，请执行 docker restart shellcrash。"
    echo "$status" > /tmp/ShellCrash/start_failed.status 2>/dev/null || true
    trap 'exit 0' INT TERM
    while :; do
        sleep 3600 &
        wait "$!"
    done
}

run_start() {
    trap '"$CRASHDIR/start.sh" stop >/dev/null 2>&1 || true; exit 0' INT TERM
    set +e
    "$CRASHDIR/start.sh" start
    status="$?"
    set -e
    wait_after_start_failure "$status"
}

if [ "$1" = "start" ] || [ "$1" = "stop" ] || [ "$1" = "restart" ] || [ "$1" = "debug" ] || [ "$1" = "init" ]; then
    if [ "$1" = "start" ] && ! has_bootstrap_config; then
        wait_for_config
    fi
    if [ "$1" = "start" ]; then
        run_start
    fi
    exec "$CRASHDIR/start.sh" "$@"
fi

exec "$@"
