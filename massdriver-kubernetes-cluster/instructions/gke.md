# Google GKE

You need the Google Cloud CLI and `kubectl`. Set the cluster name and its location (a region or a zone):

```bash
CLUSTER=production
LOCATION=us-central1
```

## Cluster values

```bash
# cluster.server (add https:// in front of the address)
echo "https://$(gcloud container clusters describe "$CLUSTER" --location "$LOCATION" --format 'value(endpoint)')"

# cluster.certificate-authority-data
gcloud container clusters describe "$CLUSTER" --location "$LOCATION" --format 'value(masterAuth.clusterCaCertificate)'
```

If the cluster has a private endpoint only, the deployment must reach the cluster's VPC, for example with a WireGuard tunnel.

## User: service account token (recommended)

Get a kubeconfig for your own Google identity:

```bash
gcloud container clusters get-credentials "$CLUSTER" --location "$LOCATION"
```

To create a ClusterRoleBinding, your Google identity needs the `container.clusterRoleBindings.create` permission, for example from the `roles/container.admin` role. Then follow **Service account token (kubectl)** from step 1.

## User: Google service account with an exec plugin

Use this method when the deployment has Google credentials, such as from a GCP service account resource. Give the Google service account access to the cluster, for example with the `roles/container.developer` IAM role. You can also bind it to a Kubernetes role with its email address as the user name.

Set `user.exec`:

| Field | Value |
|---|---|
| `apiVersion` | `client.authentication.k8s.io/v1beta1` |
| `command` | `gke-gcloud-auth-plugin` |
| `args` | (empty) |
| `env` | `GOOGLE_APPLICATION_CREDENTIALS` = the path of the key file, if the deployment does not set it |
| `interactiveMode` | `Never` |

The `gke-gcloud-auth-plugin` command must be installed where the kubeconfig is used.
