# Amazon EKS

You need the AWS CLI v2 and `kubectl`. Set the cluster name and the Region:

```bash
CLUSTER=production
export AWS_REGION=us-east-1
```

## Cluster values

```bash
# cluster.server
aws eks describe-cluster --name "$CLUSTER" --query 'cluster.endpoint' --output text

# cluster.certificate-authority-data
aws eks describe-cluster --name "$CLUSTER" --query 'cluster.certificateAuthority.data' --output text
```

If the cluster endpoint is private, the deployment must reach the cluster's VPC, for example with a WireGuard tunnel.

## User: service account token (recommended)

Get a kubeconfig for your own IAM identity:

```bash
aws eks update-kubeconfig --name "$CLUSTER"
```

Then follow **Service account token (kubectl)** from step 1. The token does not depend on AWS credentials in the deployment.

## User: IAM role with an exec plugin

Use this method when the deployment has AWS credentials, such as from an AWS IAM role resource. EKS maps the IAM role to Kubernetes permissions with an access entry:

```bash
ROLE_ARN=arn:aws:iam::123456789012:role/massdriver-deployer

aws eks create-access-entry --cluster-name "$CLUSTER" --principal-arn "$ROLE_ARN"

aws eks associate-access-policy \
  --cluster-name "$CLUSTER" \
  --principal-arn "$ROLE_ARN" \
  --policy-arn arn:aws:eks::aws:cluster-access-policy/AmazonEKSAdminPolicy \
  --access-scope type=namespace,namespaces=apps
```

The cluster's authentication mode must include `API`. To give access to the whole cluster, use `AmazonEKSClusterAdminPolicy` with `--access-scope type=cluster`.

Set `user.exec`:

| Field | Value |
|---|---|
| `apiVersion` | `client.authentication.k8s.io/v1beta1` |
| `command` | `aws` |
| `args` | `eks`, `get-token`, `--cluster-name`, `production`, `--output`, `json` |
| `env` | `AWS_REGION` = `us-east-1` |
| `interactiveMode` | `Never` |

The `aws` command must be installed where the kubeconfig is used.
