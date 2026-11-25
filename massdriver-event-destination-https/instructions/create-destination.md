# Create an event destination

An event destination receives your organization's audit log events. This resource describes a destination with the `HTTP` adapter and an `https://` URL. A bundle that runs your receiver depends on it, and uses `url` and `signing_secret`.

To manage destinations, you need the `organization:manageEventDestinations` permission.

## With the CLI

`mass event destination` needs mass 2.6.0 or later.

Check the events that the destination will receive:

```bash
mass event destination preview \
  --event-type 'deployment.*' \
  --attribute md-environment=prod \
  --condition '.data.metadata.deployment_action == "PROVISION"'
```

Create the destination. The command prints the signing secret:

```bash
mass event destination create \
  --name "Production deployments" \
  --url https://hooks.example.com/massdriver \
  --event-type 'deployment.*' \
  --attribute md-environment=prod \
  --condition '.data.metadata.deployment_action == "PROVISION"'
```

If the receiver needs credentials, such as an `Authorization` header, put them in `--auth @auth.json`, not in `--header`. The API returns `--header` values, and never returns `--auth`.

Read the destination again, with its signing secret:

```bash
mass event destination get <id> -o json
```

## In the Massdriver UI

1. Go to **Organization Settings** → **Event destinations**.
2. Click **New destination** and select the **HTTP** adapter.
3. Enter a **Name** and the **URL**.
4. Choose the **Events**, and if necessary the **Attributes** and the **Condition**.
5. Click **Create destination**. The **Overview** tab shows the ID and the signing secret.

## Fill in the resource

| Field | Value |
|---|---|
| `id` | The destination ID, a UUID |
| `name` | The destination name |
| `url` | The `https://` URL of the receiver |
| `signing_secret` | The signing secret, `whsec_...` |
| `event_types` | The selected event types. Empty for every event |
| `attributes` | The attribute filter. `{}` for none |
| `condition` | The jq condition. Leave it out for none |

Update the resource when you change the destination.

## Notes

- Massdriver refuses a URL whose host is a private address, such as `10.0.0.0/8` or `127.0.0.0/8`. To test on your computer, use a tunnel such as `ngrok http 8080` or `cloudflared tunnel --url http://localhost:8080`.
- `signing_secret` is sensitive. Massdriver masks it in the UI and the API. A person needs `resource:export` to read it from the resource.
- The receiver must respond with `2xx` within 10 seconds. Massdriver retries `408`, `429`, `5xx`, and connection errors. Any other status fails the event. Massdriver does not follow redirects.

Refer to [Event destinations](https://docs.massdriver.cloud/platform-operations/event-destinations) and the [HTTP adapter](https://docs.massdriver.cloud/platform-operations/event-destinations/http).
