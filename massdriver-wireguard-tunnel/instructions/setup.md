# Set up a WireGuard tunnel

A WireGuard tunnel lets a deployment reach a private network, such as a VPC with a private Kubernetes API server or database. A WireGuard server runs in the private network. The deployment is the client.

You need `wireguard-tools`, which installs `wg` and `wg-quick`.

## 1. Generate the keys

Generate a key pair for the client (Massdriver) and a preshared key:

```bash
umask 077
wg genkey | tee client.key | wg pubkey > client.pub
wg genpsk > tunnel.psk
```

`client.key` goes in `interface.private_key`. `tunnel.psk` goes in `peers[].preshared_key`. `client.pub` goes on the server.

If the server does not have a key pair yet, generate one on the server:

```bash
umask 077
wg genkey | tee server.key | wg pubkey > server.pub
```

`server.pub` goes in `peers[].public_key`.

## 2. Add the client to the server

Add a `[Peer]` section for the client to the server's configuration, such as `/etc/wireguard/wg0.conf`:

```ini
[Peer]
# Massdriver
PublicKey = <contents of client.pub>
PresharedKey = <contents of tunnel.psk>
AllowedIPs = 10.200.0.2/32
```

`AllowedIPs` on the server is the client's tunnel address, the same as `interface.address` in the resource. Reload the server:

```bash
sudo wg syncconf wg0 <(sudo wg-quick strip wg0)
```

The server must forward traffic from the tunnel to the private network. Turn on IP forwarding, and add a route or NAT for the tunnel network. The server's security group or firewall must allow UDP on the WireGuard port, such as `51820`.

## 3. Fill in the resource

| Field | Value |
|---|---|
| `interface.private_key` | Contents of `client.key` |
| `interface.address` | The client's tunnel address, such as `10.200.0.2/32` |
| `interface.dns` | Optional. The resolver of the private network, such as `10.0.0.2` for an AWS VPC with CIDR `10.0.0.0/16` |
| `peers[].public_key` | Contents of `server.pub` |
| `peers[].preshared_key` | Contents of `tunnel.psk` |
| `peers[].endpoint` | Public address and port of the server, such as `vpn.example.com:51820` |
| `peers[].allowed_ips` | The private networks to reach, such as `10.0.0.0/16` |
| `peers[].persistent_keepalive` | `25` |

Delete the key files from your computer after you save the resource.

## 4. Test the tunnel

Download `wg0.conf` from the resource and start the tunnel on a Linux host:

```bash
sudo install -m 600 wg0.conf /etc/wireguard/wg0.conf
sudo wg-quick up wg0
sudo wg show wg0
```

`latest handshake` shows when the tunnel works. Stop the tunnel with `sudo wg-quick down wg0`.
