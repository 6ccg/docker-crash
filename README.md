# ShellCrash Docker 运行说明

当前版本已经收敛为 Docker-only 运行形态。`menu.sh`、`init.sh`、`start.sh`
只允许在容器内作为主入口使用；路由器或宿主机原生安装不再是支持目标。

## 运行模式

支持两种 Docker 运行模式：

1. 普通 Docker 代理模式，默认模式。
   - 不需要 root。
   - 不需要 `NET_ADMIN`、`--privileged`、TUN、iptables、nftables 或策略路由。
   - 内部强制使用纯净代理模式：`firewall_area=4`、`firewall_mod=none`。
   - 对外只暴露一个代理端口和一个面板端口。

2. Docker macvlan 旁路由模式，保留模式。
   - 只在 `firewall_area=5` 时启用。
   - 这是当前唯一需要 root/防火墙能力的模式。
   - 需要容器具备 `NET_ADMIN`，并运行在已经准备好的 macvlan 网络里。
   - 本次变更不调整 macvlan 旁路由逻辑，只保留原有转发路径。

普通代理模式如果出现 TUN、iptables、nftables、`NET_ADMIN` 相关提示，优先检查
`configs/ShellCrash.cfg`，确认没有设置 `firewall_area=5`。

## 对外端口

普通 Docker 代理模式只需要发布两个端口：

| 用途 | 配置项 | 默认值 | Docker 发布 |
| --- | --- | --- | --- |
| Socks 代理端口 | `mix_port` | `7890` | TCP + UDP |
| Web 面板端口 | `db_port` | `9999` | TCP |

代理端口使用 Clash/mihomo 的 `mixed-port` 或 sing-box 的 `mixed`
入站生成，Socks 客户端连接该端口即可；Docker 侧必须同时发布 TCP 和 UDP。
普通模式不要发布 redir、tproxy、TUN 或 DNS 端口。

示例：

```shell
docker run -d \
  --name shellcrash \
  -v shellcrash-data:/etc/ShellCrash \
  -p 7890:7890/tcp \
  -p 7890:7890/udp \
  -p 9999:9999/tcp \
  <image> /etc/ShellCrash/start.sh start
```

如果不用默认端口，需要先在 `configs/ShellCrash.cfg` 中调整 `mix_port` 和
`db_port`，再同步修改 Docker 的端口发布。

## 持久化目录

容器内默认工作目录是：

```shell
/etc/ShellCrash
```

也可以通过环境变量或启动前导出的 `CRASHDIR` 指定其他目录。为了让重建容器后继续使用
上次配置、核心、订阅和规则文件，必须持久化 `CRASHDIR`。

推荐使用 named volume 挂载整个 `CRASHDIR`：

```shell
-v shellcrash-data:/etc/ShellCrash
```

如果使用宿主机 bind mount，例如：

```shell
-v /opt/shellcrash:/etc/ShellCrash
```

则 `/opt/shellcrash` 目录本身必须已经包含本项目文件；空目录 bind mount 会覆盖镜像内的
`/etc/ShellCrash`，导致脚本入口不存在。

需要保留的主要内容包括：

- `configs/`：ShellCrash 配置、运行参数、面板保存配置。
- `yamls/`：Clash/mihomo 配置、覆写、规则和自定义节点。
- `jsons/`：sing-box 配置覆写。
- `ruleset/`：规则集文件。
- `ui/`：本地 Web 面板文件。
- `task/`：自定义任务脚本。
- `tools/`：本地工具文件。
- `CrashCore.gz`、`CrashCore.tar.gz`、`CrashCore.upx`：已下载的核心包。
- `Country.mmdb`、`GeoSite.dat`：Geo 数据文件。

`TMPDIR` 默认是 `/tmp/ShellCrash`，只作为运行时临时目录，不要求持久化。

## 日志

普通 Docker 代理模式下，`start.sh start` 会直接拉起核心进程并等待它退出。核心的
stdout/stderr 会进入 Docker 日志，因此可以使用：

```shell
docker logs -f shellcrash
```

查看 ShellCrash 启动日志和核心运行日志。

## 覆写与面板

普通 Docker 代理模式会在生成最终配置时强制覆写 Docker 需要的入口项：

- Clash/mihomo：
  - `mixed-port: $mix_port`
  - `allow-lan: true`
  - `external-controller: 0.0.0.0:$db_port`
  - `external-ui: ui`
  - `external-ui-url: $external_ui_url`
  - `secret: $secret`
  - `tun.enable: false`
  - DNS 监听固定为 `127.0.0.1:$dns_port`

- sing-box：
  - 普通模式只生成 `mixed` 入站。
  - 面板通过 `experimental.clash_api` 暴露到 `0.0.0.0:$db_port`。
  - 普通模式不生成 redirect、tproxy、TUN、自定义网关入站。

因此最终用户需要连接的只有：

- `mix_port`：代理端口，TCP + UDP。
- `db_port`：Web 面板端口，TCP。

## macvlan 旁路由

macvlan 旁路由模式需要显式设置：

```shell
firewall_area=5
```

并配置对应的 `bypass_host`、防火墙后端和 Docker macvlan 网络。该模式需要 root 或等效权限，
通常还需要：

```shell
--cap-add NET_ADMIN --network <macvlan-network>
```

普通代理模式不要添加这些权限；macvlan 旁路由模式如果没有这些权限，转发能力无法正常工作。
