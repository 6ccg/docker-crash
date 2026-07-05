# ShellCrash Docker 运行说明

这个版本只面向 Docker 运行，不再支持路由器或宿主机原生安装作为主运行方式。

镜像地址：

```shell
ghcr.io/6ccg/docker-crash:latest
```

## 快速启动

推荐直接使用仓库里的 `docker-compose.yml`：

```shell
mkdir -p data
docker compose up -d
```

等价的 `docker run` 示例：

```shell
mkdir -p data
docker run -d \
  --name shellcrash \
  --restart unless-stopped \
  -v "$(pwd)/data:/data" \
  -p 7890:7890/tcp \
  -p 7890:7890/udp \
  -p 9999:9999/tcp \
  ghcr.io/6ccg/docker-crash:latest
```

镜像默认已经使用 `USER 1000:1000`，普通 compose 不需要再写 `user: "1000:1000"`。
只有在宿主机数据目录需要匹配其他 UID/GID 时，才需要在 compose 里显式覆盖 `user`。

## 首次启动

容器内项目目录是 `/etc/ShellCrash`，运行数据目录是 `/data`。

空 `/data` 首次启动时，容器会自动创建基础目录和配置文件。如果还没有订阅链接、
`/data/yamls/config.yaml` 或 `/data/jsons/config.json`，容器会保持运行，但不会启动核心。
此时可以进入容器导入配置：

```shell
docker exec -it shellcrash crash
```

导入订阅或配置后重启容器：

```shell
docker compose restart
```

## 端口

普通 Docker 代理模式只暴露两个端口：

| 用途 | 配置项 | 默认值 | Docker 发布 |
| --- | --- | --- | --- |
| Socks/HTTP mixed 代理 | `mix_port` | `7890` | TCP + UDP |
| Web 面板 | `db_port` | `9999` | TCP |

普通模式不要发布 redir、tproxy、TUN 或 DNS 端口。

如果要修改默认端口，需要同时修改 `/data/configs/ShellCrash.cfg` 和 Docker 端口映射。
也可以通过环境变量初始化端口：

```yaml
environment:
  MIX_PORT: "7890"
  DB_PORT: "9999"
```

## 持久化

必须持久化 `/data`。重建容器后，配置、核心、规则、面板缓存都会从这里恢复。

主要目录和文件：

- `/data/configs/`：ShellCrash 配置、运行参数、面板保存配置。
- `/data/yamls/`：Clash/mihomo 配置、覆写、规则和自定义节点。
- `/data/jsons/`：sing-box 配置覆写。
- `/data/ruleset/`：规则集缓存。
- `/data/ui/`：本地 Web 面板和 PAC 文件。
- `/data/task/`：自定义任务脚本。
- `/data/tools/`：本地工具文件。
- `/data/CrashCore`：已解压核心，优先用于快速启动。
- `/data/CrashCore.gz`、`/data/CrashCore.tar.gz`、`/data/CrashCore.upx`：核心压缩包缓存。
- `/data/Country.mmdb`、`/data/GeoSite.dat`：Geo 数据文件。

`/tmp/ShellCrash` 是运行时临时目录，不需要持久化。

## 日志

普通 Docker 代理模式下，核心进程直接以前台方式运行。ShellCrash 启动日志和核心运行日志都会进入 Docker 日志：

```shell
docker logs -f shellcrash
```

## 普通代理模式

默认就是普通 Docker 代理模式：

- 不需要 root。
- 不需要 `NET_ADMIN`。
- 不需要 `--privileged`。
- 不启用 TUN。
- 不写 iptables/nftables/策略路由。
- 内部强制 `firewall_area=4`、`firewall_mod=none`。

Clash/mihomo 最终配置会强制覆写：

- `mixed-port: $mix_port`
- `allow-lan: true`
- `external-controller: 0.0.0.0:$db_port`
- `external-ui: ui`
- `external-ui-url: $external_ui_url`
- `secret: $secret`
- `tun: {enable: false}`
- `experimental: {ignore-resolve-fail: true}`

sing-box 普通模式只生成 `mixed` 入站，并通过 `experimental.clash_api`
暴露面板到 `0.0.0.0:$db_port`。

## macvlan 旁路由

macvlan 旁路由是保留模式，只在显式设置 `firewall_area=5` 时启用。

这个模式是当前唯一需要 root/网络管理能力的模式，通常需要：

```yaml
cap_add:
  - NET_ADMIN
network_mode: <macvlan-network>
environment:
  SHELLCRASH_MODE: macvlan
```

同时需要在 `/data/configs/ShellCrash.cfg` 中配置 `firewall_area=5`、`bypass_host`
和对应防火墙后端。普通代理模式不要添加这些权限。

## 构建

推送到 `main` 分支后，GitHub Actions 会自动构建并发布：

```shell
ghcr.io/6ccg/docker-crash:latest
```
