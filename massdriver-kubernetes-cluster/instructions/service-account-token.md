# Service account token (kubectl)

This method works on every Kubernetes cluster. It creates a Kubernetes ServiceAccount for Massdriver, gives it a role, and makes a long-lived token for it. Run the commands with a kubeconfig that is an administrator of the cluster.

## 1. Create the ServiceAccount

```bash
kubectl create namespace massdriver
kubectl create serviceaccount massdriver --namespace massdriver
```

## 2. Give it access

Give the least access that your bundles need.

To manage one namespace only:

```bash
kubectl create namespace apps
kubectl create rolebinding massdriver-admin \
  --namespace apps \
  --clusterrole admin \
  --serviceaccount massdriver:massdriver
```

To manage the whole cluster, such as to install operators and CRDs:

```bash
kubectl create clusterrolebinding massdriver-cluster-admin \
  --clusterrole cluster-admin \
  --serviceaccount massdriver:massdriver
```

## 3. Create a token

Kubernetes 1.24 and later do not create a token Secret for a ServiceAccount. Create one:

```bash
kubectl apply -f - <<'EOF'
apiVersion: v1
kind: Secret
metadata:
  name: massdriver-token
  namespace: massdriver
  annotations:
    kubernetes.io/service-account.name: massdriver
type: kubernetes.io/service-account-token
EOF
```

The token stays valid until you delete the Secret. To rotate it, delete the Secret, create it again, and update the resource.

## 4. Get the values

```bash
# cluster.server
kubectl config view --minify --raw -o jsonpath='{.clusters[0].cluster.server}'

# cluster.certificate-authority-data
kubectl get secret massdriver-token -n massdriver -o jsonpath='{.data.ca\.crt}'

# user.token
kubectl get secret massdriver-token -n massdriver -o jsonpath='{.data.token}' | base64 --decode
```

Set `namespace` to the namespace that the token can use, such as `apps`.

## 5. Check the values

Download the kubeconfig from the resource, then run:

```bash
kubectl --kubeconfig ./kubeconfig.yaml auth can-i --list
```

## Security

- `user.token`, `user.client-key-data`, and the `exec.env` values are sensitive. Massdriver masks them in the UI and the API. A person needs `resource:export` to download the kubeconfig.
- Do not use `cluster-admin` when a namespace role is enough.
- The token works from any network that can reach the API server. Limit access to the API server to known networks when your provider supports it.
