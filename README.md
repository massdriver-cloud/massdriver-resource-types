# Massdriver Resource Types

Official [resource types](https://docs.massdriver.cloud/concepts/resources) for Massdriver. Install them in your organization to turn on Massdriver platform features. Bundles then use them as dependencies, and you can import resources of these types.

| Resource type | Icon | What it holds | Export |
|---|---|---|---|
| [`massdriver-service-account`](./massdriver-service-account) | <img src="./massdriver-service-account/icon.svg" width="32" alt=""> | Credentials of a Massdriver service account: `url`, `organization_id`, and `api_key`, the settings of the Massdriver CLI, Go SDK, and Terraform provider. | |
| [`massdriver-kubernetes-cluster`](./massdriver-kubernetes-cluster) | <img src="./massdriver-kubernetes-cluster/icon.svg" width="32" alt=""> | Access to a Kubernetes API server, in kubeconfig format: `cluster`, `user` (token, client certificate, or exec plugin), and `namespace`. | `kubeconfig.yaml` |
| [`massdriver-wireguard-tunnel`](./massdriver-wireguard-tunnel) | <img src="./massdriver-wireguard-tunnel/icon.svg" width="32" alt=""> | A WireGuard client configuration in wg-quick format, so that deployments can reach private networks of remote environments. | `wg0.conf` |

Each directory has a `massdriver.yaml` with the JSON Schema of the type, instructions that Massdriver shows when you import a resource, and export templates.

## Install

You need the [Massdriver CLI](https://github.com/massdriver-cloud/mass) and a profile or API key that can create and publish resource types (`repo:create` and `repo:push`).

```bash
git clone https://github.com/massdriver-cloud/massdriver-resource-types.git
cd massdriver-resource-types

for type in massdriver-service-account massdriver-kubernetes-cluster massdriver-wireguard-tunnel; do
  mass resource-type create "$type"
  mass resource-type publish "$type"
done
```

`mass resource-type create` makes the repository of a type in your organization. Run it once for each type. `mass resource-type publish` publishes the `version` in the type's `massdriver.yaml`. A published version cannot change.

## Use a type in a bundle

Reference the type in the `dependencies` of a bundle's `massdriver.yaml`:

```yaml
dependencies:
  kubernetes_cluster:
    resource_type: massdriver-kubernetes-cluster@~0.1
    required: true
```

Fields marked `$md.sensitive` (API keys, tokens, private keys, and signing secrets) are masked in the Massdriver UI and API. A deployment gets the full values.

## Validate

Pull requests run `scripts/validate.exs`. It checks each type against the Massdriver resource type metaschema, checks each schema and its examples with the same JSON Schema library as Massdriver (ExJsonSchema), and renders each export with each example with the same Liquid library (Solid).

```bash
curl -fsSL https://api.massdriver.cloud/json-schemas/resource-type.json -o /tmp/resource-type.json
elixir scripts/validate.exs /tmp/resource-type.json /tmp/rendered
```

## License

[Apache 2.0](./LICENSE)
