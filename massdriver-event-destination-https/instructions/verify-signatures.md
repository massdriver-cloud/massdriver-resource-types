# Verify signatures

Massdriver signs each request with the [Standard Webhooks](https://www.standardwebhooks.com) method. Each request has these headers:

| Header | Value |
|---|---|
| `webhook-id` | The CloudEvent `id`. It is the same for each attempt of an event. Use it to drop duplicates. |
| `webhook-timestamp` | The time of the attempt, in seconds since the Unix epoch. |
| `webhook-signature` | `v1,` followed by the base64 signature. It can hold more than one signature, separated by spaces. |

The signature is the HMAC-SHA256 of `<webhook-id>.<webhook-timestamp>.<body>`. The key is the base64-decoded part of `signing_secret` after `whsec_`.

To verify a request:

1. Read the raw body. Do not parse and encode the JSON again before you verify it.
2. Refuse a `webhook-timestamp` that is more than 5 minutes from your current time. This stops replays.
3. Calculate the signature, and compare it to each `v1` value in `webhook-signature` with a constant-time comparison.
4. If no value is equal, respond with `401`. Massdriver does not retry a `401`.

Each example reads the secret from `MASSDRIVER_SIGNING_SECRET` and uses only the standard library. The [Standard Webhooks libraries](https://github.com/standard-webhooks/standard-webhooks/tree/main/libraries) also verify these requests.

## Go

```go
package webhook

import (
	"crypto/hmac"
	"crypto/sha256"
	"encoding/base64"
	"net/http"
	"strconv"
	"strings"
	"time"
)

const tolerance = 5 * time.Minute

// Verify reports whether body and headers carry a valid signature for secret.
func Verify(secret string, headers http.Header, body []byte) bool {
	id := headers.Get("webhook-id")
	timestamp := headers.Get("webhook-timestamp")
	signatures := headers.Get("webhook-signature")
	if id == "" || timestamp == "" || signatures == "" {
		return false
	}

	seconds, err := strconv.ParseInt(timestamp, 10, 64)
	if err != nil {
		return false
	}
	if age := time.Since(time.Unix(seconds, 0)); age > tolerance || age < -tolerance {
		return false
	}

	key, err := base64.StdEncoding.DecodeString(strings.TrimPrefix(secret, "whsec_"))
	if err != nil {
		return false
	}
	mac := hmac.New(sha256.New, key)
	mac.Write([]byte(id + "." + timestamp + "."))
	mac.Write(body)
	expected := mac.Sum(nil)

	for _, signature := range strings.Split(signatures, " ") {
		version, value, found := strings.Cut(signature, ",")
		if !found || version != "v1" {
			continue
		}
		actual, err := base64.StdEncoding.DecodeString(value)
		if err == nil && hmac.Equal(actual, expected) {
			return true
		}
	}
	return false
}
```

In a handler, read the body with `io.ReadAll(r.Body)` before you call `Verify`.

## Python

Python 3.9 or later.

```python
import base64
import hashlib
import hmac
import time

TOLERANCE_SECONDS = 5 * 60


def verify(secret: str, headers, body: bytes) -> bool:
    msg_id = headers.get("webhook-id")
    timestamp = headers.get("webhook-timestamp")
    signatures = headers.get("webhook-signature")

    if not (msg_id and timestamp and signatures and timestamp.isdigit()):
        return False
    if abs(time.time() - int(timestamp)) > TOLERANCE_SECONDS:
        return False

    key = base64.b64decode(secret.removeprefix("whsec_"))
    signed = f"{msg_id}.{timestamp}.".encode() + body
    expected = base64.b64encode(hmac.new(key, signed, hashlib.sha256).digest()).decode()

    for signature in signatures.split(" "):
        version, _, value = signature.partition(",")
        if version == "v1" and hmac.compare_digest(value, expected):
            return True

    return False
```

## Node.js

Node.js 18 or later.

```js
import { createHmac, timingSafeEqual } from "node:crypto";

const TOLERANCE_SECONDS = 5 * 60;

export function verify(secret, headers, body) {
  const id = headers["webhook-id"];
  const timestamp = headers["webhook-timestamp"];
  const signatures = headers["webhook-signature"];

  if (!id || !/^\d+$/.test(timestamp ?? "") || !signatures) return false;
  if (Math.abs(Date.now() / 1000 - Number(timestamp)) > TOLERANCE_SECONDS) return false;

  const key = Buffer.from(secret.replace(/^whsec_/, ""), "base64");
  const expected = createHmac("sha256", key).update(`${id}.${timestamp}.`).update(body).digest();

  return signatures.split(" ").some((signature) => {
    const [version, value] = signature.split(",");
    if (version !== "v1" || !value) return false;
    const actual = Buffer.from(value, "base64");
    return actual.length === expected.length && timingSafeEqual(actual, expected);
  });
}
```

`body` is the raw request body as a `Buffer`. With Express, use `express.raw({ type: "application/cloudevents+json" })`.

## Test the receiver

Click **Send test event** on the destination in the Massdriver UI. Massdriver sends one `event_destination.tested` event and shows the response, such as `HTTP 401` when the signature check fails.
