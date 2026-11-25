# Security

- **Private and preshared keys are secrets.** `interface.private_key` and `peers[].preshared_key` are sensitive. Massdriver masks them in the UI and the API. A person needs `resource:export` to download `wg0.conf`. Generate keys with `umask 077` and delete the key files after you save the resource.
- **One key pair for each tunnel.** Do not use the same client key for Massdriver and other clients. Then you can revoke Massdriver's access alone: remove its `[Peer]` section from the server.
- **Limit the networks.** Set `peers[].allowed_ips` to the networks that deployments need, not `0.0.0.0/0`. On the server, allow traffic from the client's tunnel address only to the hosts and ports that deployments use.
- **Use a preshared key.** It adds a symmetric key to the handshake, which protects recorded traffic against future quantum computers.
- **Rotate the keys.** To rotate, generate a new key pair and preshared key, add the new `[Peer]` to the server, update the resource, then remove the old `[Peer]` from the server.
- **No hooks.** The resource has no `PreUp`, `PostUp`, `PreDown`, or `PostDown` fields. These wg-quick fields run shell commands as root, so a resource cannot carry them.
- **Expose only the WireGuard port.** The server needs one UDP port open to the internet. WireGuard does not answer packets from senders that do not know the server's public key, so a port scan gets no response.
