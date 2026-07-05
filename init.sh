#!/bin/sh
# Copyright (C) Juewuy

# 容器内环境
grep -qE '/(docker|lxc|kubepods|crio|containerd)/' /proc/1/cgroup || [ -f /run/.containerenv ] || [ -f /.dockerenv ] && systype='container'

[ -z "$CRASHDIR" ] && [ -n "$clashdir" ] && CRASHDIR="$clashdir"
[ "$systype" = 'container' ] && [ -z "$CRASHDIR" ] && CRASHDIR='/etc/ShellCrash'
[ "$systype" != 'container' ] && {
    echo -e "\033[31m当前版本仅支持 Docker 运行！\033[0m"
    exit 1
}

mkdir -p "$CRASHDIR"
CFG_PATH="$CRASHDIR"/configs/ShellCrash.cfg
. "$CRASHDIR"/libs/set_config.sh
. "$CRASHDIR"/libs/docker_data.sh

mkdir -p "$CRASHDIR"/configs "$CRASHDIR"/yamls "$CRASHDIR"/jsons "$CRASHDIR"/tools "$CRASHDIR"/task "$CRASHDIR"/ruleset
init_docker_data_defaults
my_alias=$(grep '^my_alias=' "$CFG_PATH" 2>/dev/null | tail -n 1 | cut -d= -f2-)

# 批量授权
command -v bash >/dev/null 2>&1 && shtype=bash
[ -x /bin/ash ] && shtype=ash
for file in start.sh starts/bfstart.sh starts/afstart.sh starts/fw_stop.sh menu.sh menus/task_cmd.sh menus/bot_tg.sh; do
    sed -i "s|/bin/sh|/bin/$shtype|" "$CRASHDIR/$file" 2>/dev/null
    chmod +x "$CRASHDIR/$file" 2>/dev/null
done
version=$(cat "$CRASHDIR"/version 2>/dev/null)
[ -n "$version" ] && setconfig versionsh_l "$version"

[ -w /usr/bin ] && cat > /usr/bin/crash <<'EOF'
#!/bin/sh
CRASHDIR=${CRASHDIR:-/etc/ShellCrash}
export CRASHDIR
exec "$CRASHDIR/menu.sh" "$@"
EOF
[ -w /usr/bin/crash ] && chmod 755 /usr/bin/crash

# 转换旧版本文件布局，只处理容器数据目录内仍有意义的配置和缓存。
for file in config.yaml.bak user.yaml proxies.yaml proxy-groups.yaml rules.yaml others.yaml; do
    mv -f "$CRASHDIR"/"$file" "$CRASHDIR"/yamls/"$file" 2>/dev/null
done
[ ! -L "$CRASHDIR"/config.yaml ] && mv -f "$CRASHDIR"/config.yaml "$CRASHDIR"/yamls/config.yaml 2>/dev/null
mv -f "$CRASHDIR"/configs/ShellClash.cfg "$CFG_PATH" 2>/dev/null
mv -f "$CRASHDIR"/geosite.dat "$CRASHDIR"/GeoSite.dat 2>/dev/null
mv -f "$CRASHDIR"/ruleset/geosite-cn.srs "$CRASHDIR"/ruleset/cn.srs 2>/dev/null
mv -f "$CRASHDIR"/ruleset/geosite-cn.mrs "$CRASHDIR"/ruleset/cn.mrs 2>/dev/null
mv -f "$CRASHDIR"/*.srs "$CRASHDIR"/ruleset/ 2>/dev/null
mv -f "$CRASHDIR"/*.mrs "$CRASHDIR"/ruleset/ 2>/dev/null
for file in cron task.list; do
    mv -f "$CRASHDIR"/"$file" "$CRASHDIR"/task/"$file" 2>/dev/null
done

rm -rf "$CRASHDIR"/rules
for file in webget.sh core.new; do
    rm -f "$CRASHDIR/$file"
done

# 旧版变量改名
sed -i "s/clashcore/crashcore/g" "$CFG_PATH"
sed -i "s/clash_v/core_v/g" "$CFG_PATH"
sed -i "s/clash.meta/meta/g" "$CFG_PATH"
sed -i "s/ShellClash/ShellCrash/g" "$CFG_PATH"
sed -i "s/cpucore=armv8/cpucore=arm64/g" "$CFG_PATH"
sed -i "s/redir_mod=Nft基础/redir_mod=Redir模式/g" "$CFG_PATH"
sed -i "s/redir_mod=Nft混合/redir_mod=Tproxy模式/g" "$CFG_PATH"
sed -i "s/redir_mod=Tproxy混合/redir_mod=Tproxy模式/g" "$CFG_PATH"
sed -i "s/redir_mod=纯净模式/firewall_area=4/g" "$CFG_PATH"
sed -i 's/=\(已启用\|已开启\)$/=ON/'  "$CFG_PATH"
sed -i 's/=\(未启用\|未开启\)$/=OFF/' "$CFG_PATH"

rm -rf /tmp/*rash*gz /tmp/SC_tmp
echo -e "\033[32m脚本初始化完成,请输入\033[30;47m $my_alias \033[0;33m命令开始使用！\033[0m"
