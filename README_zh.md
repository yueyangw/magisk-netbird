# Magisk NetBird

Magisk NetBird 用于在已 root 的 Android 设备上以开机服务方式运行 Linux 版 NetBird 客户端。当前版本让 NetBird 自己创建和维护 WireGuard 接口，不再额外使用 SOCKS 桥接层。

## Quickstart

1. 在 Magisk / KernelSU 中刷入模块，然后重启设备。
2. 打开 root shell，确认服务已启动：

```sh
su -c 'netbird.service status'
```

3. 登录 NetBird Cloud：

```sh
su -c 'netbird up'
```

如果设备上不方便打开浏览器，可以显示二维码或只打印登录链接：

```sh
su -c 'netbird up --qr'
su -c 'netbird up --no-browser'
```

4. 检查 NetBird 状态和接口：

```sh
su -c 'netbird status'
su -c 'ip addr'
```

如果你使用 setup key，登录命令可以改成：

```sh
su -c 'netbird up --setup-key <setup-key>'
```

## 自部署服务器登录

自部署 NetBird 时，客户端需要知道你的 Management URL。常见一键部署里，Management URL 和 Admin URL 通常是同一个域名，例如：

```text
https://netbird.example.com:443
```

### 使用 setup key 登录

这是最适合 Android root shell 的方式。先在 NetBird 管理后台创建 setup key，然后执行：

```sh
su -c 'netbird up --management-url https://netbird.example.com:443 --admin-url https://netbird.example.com:443 --setup-key <setup-key>'
```

如果你的自部署没有配置 SSO，通常也应该使用 setup key。

### 使用自部署 SSO 登录

如果你的自部署 NetBird 已经配置了 SSO，可以不带 setup key：

```sh
su -c 'netbird up --management-url https://netbird.example.com:443 --admin-url https://netbird.example.com:443 --no-browser'
```

命令会输出登录 URL。把 URL 复制到浏览器完成授权后，再检查状态：

```sh
su -c 'netbird.service status'
su -c 'netbird status'
```

### 常见自部署检查项

- 确认 Android 设备能访问 `https://netbird.example.com:443`。
- 确认证书被 Android 信任。
- 确认 NetBird Dashboard 里已经允许 setup key 注册新 peer。
- 自部署 SSO 建议同时传 `--management-url` 和 `--admin-url`。本模块会在 `netbird up` 和 `netbird login` 中自动把缺失的 `--admin-url` 补成相同的 Management URL。
- 如果 `netbird up --no-browser` 长时间没有输出，先看 daemon 日志：`su -c 'tail -80 /data/adb/netbird/run/netbird.log'`。
- 本模块会提供 `/system/etc/resolv.conf` 和 `resolvconf` 适配器，避免 Linux 版 NetBird 在 Android 上把 DNS 退回到不可用的默认路径；更新模块后需要重启设备让 systemless 文件生效。

## 工作原理

模块只负责安装二进制、配置运行目录、开机启动 daemon：

```text
netbird service run
  -> NetBird 创建并配置 WireGuard 接口
  -> NetBird 从 Management 获取 peer、路由和 DNS 配置
  -> NetBird 把接口路由写入 main 路由表
  -> 模块把 wt0 上的路由同步进 Android 专用 policy route table
  -> 模块把 Android DNS 查询转给 NetBird 本地 DNS listener
```

接口名由 NetBird 配置决定，通常是 `wt0`。真实的 NetBird IP 应该出现在 `netbird status` 和 `ip addr` 里。

Android 会优先使用按网络划分的 policy routing table。Linux 版 NetBird 写入的是普通 Linux 路由，所以服务脚本会把 NetBird 接口上已经存在的前缀镜像到 `10090` 路由表，并把这些前缀的 `ip rule` 优先级设为 `9000`，这样它们会排在常见 Android VPN 规则之前。即使其他 VPN 在 `main` 表里留下更具体的路由，NetBird 前缀也会先查 `10090` 表；WireGuard 接口和 peer 状态仍由 NetBird 自己维护。

Android 的系统解析器不总是读取 root shell 里看到的 `/etc/resolv.conf`。服务会保持 NetBird DNS 开启，并默认监听 `127.0.0.1:1053`；启动前用 `resolvconf` 适配器让 NetBird 读到原始上游 DNS，随后把模块的 systemless `resolv.conf` 指向 localhost，并把 DNS 流量重定向给 NetBird。这样 NetBird 不占用任何 `:53` 监听，避免和 Android 热点/共享网络的 DNS forwarder 冲突。NetBird 会自己处理 peer 域名、自定义 NetBird DNS zone，以及公网 fallback 解析。在 KernelSU 上，daemon 会以 UID 0、GID `3003` 启动；服务会把 NetBird 前缀规则保持在优先级 `9000`，再用优先级 `9010` 为 UID 0 增加到底层 Android 网络表的旁路，并给 daemon 包打 Android protected-from-VPN 标记。这样 NetBird 控制面不会被系统 VPN 吞掉，普通应用流量仍然留在系统 VPN。Android netd/root shell 的 DNS 查询在使用普通 DNS socket 时仍会进入 NetBird，但 Android 自己的 VPN resolver 缓存可能要等 VPN/网络刷新后才清掉旧失败。

部分 Android 内核会拒绝 NetBird Linux 客户端生成的 ipset ACL 规则。此时 NetBird 仍会在 WireGuard 接口后面留下默认 DROP，表现就是本机主动访问其他 peer 正常，但其他设备访问 Android 上的服务失败。服务脚本会在该 DROP 前维护一条 NetBird 接口入站放行规则，让其他 peer 可以通过 NetBird 名称/IP 访问这台 Android 设备上的服务。

## 运行目录

- `/data/adb/netbird/bin/netbird`
- `/data/adb/netbird/bin/jq`
- `/data/adb/netbird/scripts/netbird.service`
- `/data/adb/netbird/run/netbird.sock`
- `/data/adb/netbird/run/netbird.log`
- `/data/adb/netbird/default.json`
- `/system/etc/resolv.conf`

## 常用命令

启动服务：

```sh
su -c 'netbird.service start'
```

查看状态：

```sh
su -c 'netbird.service status'
su -c 'netbird status'
```

查看日志：

```sh
su -c 'netbird.service log daemon'
su -c 'netbird.service log service'
```

停止服务：

```sh
su -c 'netbird.service stop'
```

## 限制

- 依赖设备可用的 root 权限和 `/dev/net/tun`。
- 接口、peer 路由、main 表里的 network route 都由 NetBird 自己维护。
- 服务会在 Android 上关闭 NetBird Linux fwmark 高级路由，并为 `wt0` 前缀维护 Android policy rule。
- daemon/root 控制面会走底层 Android 网络表，这样系统 VPN 和 NetBird 可以共存，同时普通应用流量不会被移出 VPN。
- 默认关闭 NetBird IPv6 overlay，因为很多 Android 内核没有 Linux 客户端 firewall 期望的 `ip6tables nat` 表。
- 当 Android 拒绝 NetBird 的 ipset ACL 规则时，服务会保持 NetBird 接口入站流量可达。
- 模块会提供 `/system/etc/resolv.conf`、`resolvconf` 适配器，并维护 DNS 重定向规则，因为 Linux 版 NetBird 本身不会接入 Android netd resolver。

## 排障

检查 daemon 是否运行：

```sh
su -c 'netbird.service status'
```

检查 NetBird 分配的 IP 和接口：

```sh
su -c 'netbird status'
su -c 'ip addr'
```

检查路由：

```sh
su -c 'ip route'
su -c 'ip rule'
```

查看 daemon 日志：

```sh
su -c 'netbird.service log daemon'
```
