# Magisk NetBird

[中文](README_zh.md)

Magisk NetBird runs the Linux NetBird client on rooted Android as a boot service. NetBird now uses its own NetBird-managed WireGuard interface, so the module no longer adds a separate SOCKS bridge or secondary transparent-routing daemon.

## How It Works

The module starts:

```text
netbird service run
  -> NetBird creates and configures its WireGuard interface
  -> NetBird receives peers, routes, and DNS settings from Management
  -> NetBird installs interface routes into the main route table
  -> The module mirrors wt0 routes into an Android policy route table
  -> The module sends Android DNS queries to NetBird's local DNS listener
```

The interface name is controlled by NetBird itself and is usually `wt0`. Check `netbird status` and `ip addr` for the actual name and assigned NetBird IP.

Android uses per-network policy routing tables. The Linux NetBird binary writes normal Linux routes, so the service mirrors the prefixes already present on the NetBird interface into table `10090` and adds `ip rule` entries for those prefixes at priority `9000`, which keeps them ahead of common Android VPN rules. This avoids conflicts where another VPN leaves more-specific routes in `main`, while the WireGuard interface and peer state remain NetBird-managed.

Android's system resolver does not reliably use `/etc/resolv.conf` from root shell commands. The service keeps NetBird DNS enabled on `127.0.0.1:1053`, prepares a small `resolvconf` shim so NetBird can learn the original upstream resolvers, updates the module's systemless `resolv.conf` to point at localhost, and redirects DNS traffic to NetBird. Keeping NetBird off every `:53` listener avoids colliding with Android tethering/hotspot DNS forwarders. NetBird then handles peer names, custom NetBird DNS zones, and public fallback resolution itself. On KernelSU, the daemon is started as UID 0 with GID `3003`; the service keeps NetBird prefixes at priority `9000`, adds a UID 0 bypass at priority `9010` to the current underlying Android network table, and marks daemon packets with Android's protected-from-VPN bit. This keeps NetBird's control-plane sockets out of the system VPN without changing ordinary app routing. Android netd/root shell DNS queries still enter NetBird when they use normal DNS sockets, although Android's own VPN resolver cache can still report stale failures until the VPN/network refreshes.

Some Android kernels reject NetBird's Linux ipset ACL rules. When that happens, NetBird leaves a default DROP on the WireGuard interface, which blocks inbound traffic even while outbound traffic works. The service adds an accept rule for the NetBird interface before that DROP so peers can reach Android-hosted services by the device's NetBird name/IP.

## Runtime Layout

- `/data/adb/netbird/bin/netbird`
- `/data/adb/netbird/bin/jq`
- `/data/adb/netbird/scripts/netbird.service`
- `/data/adb/netbird/run/netbird.sock`
- `/data/adb/netbird/run/netbird.log`
- `/data/adb/netbird/default.json`
- `/system/etc/resolv.conf`

## Commands

Start the daemon:

```sh
su -c 'netbird.service start'
```

Log in with a setup key:

```sh
su -c 'netbird up --setup-key <setup-key>'
```

Log in to a self-hosted server:

```sh
su -c 'netbird up --management-url https://netbird.example.com:443 --admin-url https://netbird.example.com:443 --setup-key <setup-key>'
```

Check status:

```sh
su -c 'netbird.service status'
su -c 'netbird status'
su -c 'ip addr'
```

View logs:

```sh
su -c 'netbird.service log daemon'
su -c 'netbird.service log service'
```

Stop the daemon:

```sh
su -c 'netbird.service stop'
```

## Notes

- The module depends on Android root access and a working `/dev/net/tun`.
- NetBird owns interface creation, peer routing, and main-table network routes.
- The service disables NetBird's Linux fwmark advanced routing on Android and uses Android policy rules plus route table `10090` for `wt0` prefixes.
- The daemon/root control-plane path is routed through the underlying Android network table so Android system VPN and NetBird can coexist without moving ordinary app traffic out of the VPN.
- NetBird IPv6 overlay is disabled by default because many Android kernels do not provide the `ip6tables nat` table expected by the Linux client firewall.
- The service keeps inbound traffic reachable on the NetBird interface when Android rejects NetBird's ipset-backed ACL rules.
- The module still provides `/system/etc/resolv.conf`, a `resolvconf` shim, and DNS redirect rules because Linux NetBird builds on Android do not integrate with Android's netd resolver by themselves.
- The wrapper automatically mirrors `--management-url` into `--admin-url` for `netbird up` and `netbird login` when `--admin-url` is omitted.

## Troubleshooting

Check whether the daemon is running:

```sh
su -c 'netbird.service status'
```

Check the NetBird-assigned IP and interface:

```sh
su -c 'netbird status'
su -c 'ip addr'
```

Check routes:

```sh
su -c 'ip route'
su -c 'ip rule'
```

Check daemon logs:

```sh
su -c 'netbird.service log daemon'
```
