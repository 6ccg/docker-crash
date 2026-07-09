#!/bin/sh

init_docker_data_defaults() {
    CRASHDIR="${CRASHDIR:-/etc/ShellCrash}"
    DATADIR="${SHELLCRASH_DATADIR:-/data}"
    DEFAULTS_DIR="${SHELLCRASH_DEFAULTS_DIR:-/usr/local/share/shellcrash/defaults}"
    TMPDIR="${TMPDIR:-/tmp/ShellCrash}"
    BINDIR="$DATADIR"

    for dir in configs yamls jsons ruleset ui task tools; do
        mkdir -p "$DATADIR/$dir"
    done
    mkdir -p "$TMPDIR"

    docker_install_default_dir "$DEFAULTS_DIR/configs" "$DATADIR/configs"
    docker_install_default_dir "$DEFAULTS_DIR/task" "$DATADIR/task"
    docker_install_default_dir "$DEFAULTS_DIR/data" "$DATADIR"
    docker_install_default_file "$CRASHDIR/menus/task_cmd.sh" "$DATADIR/task/task.sh"
    [ -f "$DATADIR/task/task.sh" ] && chmod 755 "$DATADIR/task/task.sh" 2>/dev/null

    for file in fake_ip_filter gateway.cfg ip_filter mac providers.cfg web_save; do
        docker_ensure_empty_file "$DATADIR/configs/$file"
    done
    docker_ensure_empty_file "$DATADIR/task/task.user"

    cfg="$DATADIR/configs/ShellCrash.cfg"
    [ -f "$cfg" ] || printf '%s\n' '#ShellCrash配置文件，不明勿动！' >"$cfg"

    docker_set_config systype container "$cfg"
    docker_set_config start_old OFF "$cfg"
    docker_set_config_if_missing userguide 1 "$cfg"
    docker_set_config_if_missing my_alias crash "$cfg"
    docker_set_config_if_missing crashcore meta "$cfg"
    docker_set_config_if_missing dns_mod mix "$cfg"
    docker_set_config_if_missing skip_cert CONFIG "$cfg"
    docker_set_config_if_missing release_type master "$cfg"
    docker_set_config zip_type tar.gz "$cfg"

    if [ "${SHELLCRASH_MODE:-proxy}" != "macvlan" ]; then
        docker_set_config firewall_area 4 "$cfg"
        docker_set_config firewall_mod none "$cfg"
    fi
    [ -n "${MIX_PORT:-}" ] && docker_set_config mix_port "$MIX_PORT" "$cfg"
    [ -n "${DB_PORT:-}" ] && docker_set_config db_port "$DB_PORT" "$cfg"

    cmd="$DATADIR/configs/command.env"
    if [ -f "$cmd" ] && grep -q 'run -D' "$cmd"; then
        command='COMMAND="$TMPDIR/CrashCore run -D $BINDIR -C $TMPDIR/jsons"'
    elif grep -q '^crashcore=singbox' "$cfg" 2>/dev/null; then
        command='COMMAND="$TMPDIR/CrashCore run -D $BINDIR -C $TMPDIR/jsons"'
    else
        command='COMMAND="$TMPDIR/CrashCore -d $BINDIR -f $TMPDIR/config.yaml"'
    fi
    cat >"$cmd" <<EOF
TMPDIR=$TMPDIR
BINDIR=$BINDIR
$command
EOF
}

docker_install_default_file() {
    src="$1"
    dst="$2"
    [ -s "$dst" ] && return 0
    [ -f "$src" ] || return 0
    cp -f "$src" "$dst"
}

docker_install_default_dir() {
    srcdir="$1"
    dstdir="$2"
    [ -d "$srcdir" ] || return 0
    for src in "$srcdir"/*; do
        [ -f "$src" ] || continue
        docker_install_default_file "$src" "$dstdir/$(basename "$src")"
    done
}

docker_ensure_empty_file() {
    [ -e "$1" ] && return 0
    : >"$1"
}

docker_set_config() {
    key="$1"
    value="$2"
    file="$3"
    touch "$file"
    sed -i "/^${key}=.*/d" "$file"
    printf '%s=%s\n' "$key" "$value" >>"$file"
}

docker_set_config_if_missing() {
    key="$1"
    value="$2"
    file="$3"
    grep -q "^${key}=" "$file" 2>/dev/null && return 0
    docker_set_config "$key" "$value" "$file"
}
