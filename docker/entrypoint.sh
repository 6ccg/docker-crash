#!/bin/sh
set -eu

CRASHDIR="${CRASHDIR:-/etc/ShellCrash}"
DATADIR="${SHELLCRASH_DATADIR:-/data}"
export CRASHDIR

for dir in configs yamls jsons ruleset ui task tools; do
    mkdir -p "$DATADIR/$dir"
done
mkdir -p /tmp/ShellCrash

if [ -x "$DATADIR/CrashCore" ]; then
    cp -f "$DATADIR/CrashCore" /tmp/ShellCrash/CrashCore
    chmod 755 /tmp/ShellCrash/CrashCore
elif [ -f "$DATADIR/CrashCore.gz" ]; then
    gunzip -c "$DATADIR/CrashCore.gz" >/tmp/ShellCrash/CrashCore
    chmod 755 /tmp/ShellCrash/CrashCore
fi

set_config() {
    key="$1"
    value="$2"
    file="$3"
    touch "$file"
    sed -i "/^${key}=.*/d" "$file"
    printf '%s=%s\n' "$key" "$value" >>"$file"
}

cfg="$DATADIR/configs/ShellCrash.cfg"
[ -f "$cfg" ] || printf '%s\n' '#ShellCrash配置文件，不明勿动！' >"$cfg"

set_config systype container "$cfg"
if [ "${SHELLCRASH_MODE:-proxy}" != "macvlan" ]; then
    set_config firewall_area 4 "$cfg"
    set_config firewall_mod none "$cfg"
    set_config start_old OFF "$cfg"
fi
[ -n "${MIX_PORT:-}" ] && set_config mix_port "$MIX_PORT" "$cfg"
[ -n "${DB_PORT:-}" ] && set_config db_port "$DB_PORT" "$cfg"

cmd="$DATADIR/configs/command.env"
if [ -f "$cmd" ] && grep -q 'run -D' "$cmd"; then
    command='COMMAND="$TMPDIR/CrashCore run -D $BINDIR -C $TMPDIR/jsons"'
else
    command='COMMAND="$TMPDIR/CrashCore -d $BINDIR -f $TMPDIR/config.yaml"'
fi
cat >"$cmd" <<EOF
TMPDIR=/tmp/ShellCrash
BINDIR=$DATADIR
$command
EOF

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
