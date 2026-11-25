# Azure AKS

You need the Azure CLI and `kubectl`. Set the resource group and the cluster name:

```bash
RESOURCE_GROUP=platform
CLUSTER=production
```

## Cluster values

Get a kubeconfig in a file, then read the values from it:

```bash
az aks get-credentials --resource-group "$RESOURCE_GROUP" --name "$CLUSTER" --file ./aks.kubeconfig

# cluster.server
kubectl --kubeconfig ./aks.kubeconfig config view --raw -o jsonpath='{.clusters[0].cluster.server}'

# cluster.certificate-authority-data
kubectl --kubeconfig ./aks.kubeconfig config view --raw -o jsonpath='{.clusters[0].cluster.certificate-authority-data}'
```

If the cluster is private, the deployment must reach the cluster's virtual network, for example with a WireGuard tunnel.

## User: service account token (recommended)

Use the kubeconfig from above, and follow **Service account token (kubectl)** from step 1:

```bash
export KUBECONFIG=./aks.kubeconfig
```

If the cluster uses Azure RBAC for Kubernetes authorization, your Entra identity needs the **Azure Kubernetes Service RBAC Cluster Admin** role, or a cluster role that can create RoleBindings. If the cluster has local accounts turned off, the token method still works, because ServiceAccount tokens are not local accounts.

Delete `./aks.kubeconfig` when you are done.

## User: Entra ID service principal with an exec plugin

Use this method when the cluster uses Microsoft Entra ID authentication. Give the service principal access to the cluster, for example with the **Azure Kubernetes Service RBAC Writer** role on a namespace.

Set `user.exec`:

| Field | Value |
|---|---|
| `apiVersion` | `client.authentication.k8s.io/v1beta1` |
| `command` | `kubelogin` |
| `args` | `get-token`, `--login`, `spn`, `--environment`, `AzurePublicCloud`, `--server-id`, `6dae42f8-4368-4678-94ff-3960e28e3630`, `--tenant-id`, your tenant ID, `--client-id`, the application ID of the service principal |
| `env` | `AAD_SERVICE_PRINCIPAL_CLIENT_SECRET` = the client secret |
| `interactiveMode` | `Never` |

`6dae42f8-4368-4678-94ff-3960e28e3630` is the application ID of the AKS server, the same in every tenant. The `kubelogin` command must be installed where the kubeconfig is used.
