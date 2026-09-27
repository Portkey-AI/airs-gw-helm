# Google Vertex AI Workload Identity Configuration

This document describes how to configure AIRS Gateway to call Google Vertex AI
(including Anthropic Claude on Vertex) using Google Workload Identity — on GKE
via the metadata server, or off GKE (EKS/EC2/any host) via Workload Identity
Federation — instead of a static service account key.

## Overview

To use Vertex AI with AIRS Gateway, the gateway needs a Google OAuth 2 access
token. You can supply a service account JSON key on the integration, but Workload
Identity is the more secure and recommended approach — no long-lived credential
is stored in the control plane or in the cluster.

Workload Identity requires **two** settings, one on each side. Configuring only
one of them is the most common cause of Vertex authentication failures:

| Where | Setting | Value |
|-------|---------|-------|
| Integration / Virtual Key (control plane) | Vertex auth type | `workload` |
| Gateway deployment (`values.yaml`) | `environment.data.GCP_AUTH_MODE` | `workload` |

The integration setting selects the workload-identity code path; the
`GCP_AUTH_MODE` environment variable is what permits that path to actually request
a token. If `GCP_AUTH_MODE` is unset, the gateway sends the request with no
bearer token and Vertex rejects it.

The gateway then obtains the token in one of two ways depending on where it runs:

- **On GKE** — from the GKE metadata server, using the identity bound to its pod
  (`GCP_WIF_AUDIENCE` unset). See Step 2, Option A.
- **Off GKE** (EKS, EC2, or any non-GCP host) — via Workload Identity Federation,
  exchanging the platform's native identity (e.g. an AWS IAM role) for a Google
  token (`GCP_WIF_AUDIENCE` set). No metadata server, no static key. See Step 2,
  Option B.

## Step 1: Create the Vertex AI Service Account

Create a service account and grant it the Vertex AI user role on the project that
serves your models:

```bash
gcloud iam service-accounts create <GSA> --project <GSA_PROJECT_ID>

gcloud projects add-iam-policy-binding <MODEL_PROJECT_ID> \
  --member "serviceAccount:<GSA>@<GSA_PROJECT_ID>.iam.gserviceaccount.com" \
  --role roles/aiplatform.user
```

The project that owns the models need not be the project the cluster runs in —
grant `roles/aiplatform.user` on whichever project serves the models. (For direct
resource access off GKE, you can skip the service account and grant the federated
principal instead — see Step 2, Option B.)

## Step 2: Bind the Workload Identity

Choose the option matching where the gateway runs.

### Option A: GKE (metadata server)

Allow the gateway's Kubernetes service account to impersonate the GSA, then
annotate it:

```bash
gcloud iam service-accounts add-iam-policy-binding \
  <GSA>@<GSA_PROJECT_ID>.iam.gserviceaccount.com \
  --role roles/iam.workloadIdentityUser \
  --member "serviceAccount:<CLUSTER_PROJECT_ID>.svc.id.goog[<NAMESPACE>/<KSA>]"
```

```yaml
serviceAccount:
  create: true
  automount: true
  name: <KSA>
  annotations:
    iam.gke.io/gcp-service-account: <GSA>@<GSA_PROJECT_ID>.iam.gserviceaccount.com
```

Leave `GCP_WIF_AUDIENCE` unset — the gateway requests an access token from the GKE
metadata server and caches it for the lifetime of the token.

### Option B: Off GKE — Workload Identity Federation

Off GKE (EKS, EC2, or any non-GCP host), the gateway federates the pod's own
cloud identity into Google via Workload Identity Federation, then calls Vertex —
no metadata server, no static key. The pod must already receive that identity
(e.g. IRSA or EKS Pod Identity on EKS); `GCP_WIF_AUDIENCE` alone is not enough.

Standing up the WIF pool/provider and mapping your cloud's identity attributes is
standard, provider-specific GCP setup and is **out of scope for this doc** — see
Google's
[Workload Identity Federation guide](https://cloud.google.com/iam/docs/workload-identity-federation-with-other-providers).
Once the pool/provider exist, point the gateway at their audience with
`GCP_WIF_AUDIENCE` (Step 3), then grant the resulting federated principal access
to Vertex using **one** of the following. `<FEDERATED_PRINCIPALSET>` below is the
`principalSet://…` identifying that principal (from your WIF provider).

**Direct resource access** — grant the model role to the federated principal on
each model project:

```bash
gcloud projects add-iam-policy-binding <MODEL_PROJECT_ID> \
  --role roles/aiplatform.user \
  --member "<FEDERATED_PRINCIPALSET>"
```

**Service account impersonation** (recommended) — grant the federated principal
permission to impersonate the GSA from Step 1 (requires the Service Account
Credentials API, `iamcredentials.googleapis.com`), then set
`GCP_WIF_SERVICE_ACCOUNT_EMAIL` in Step 3:

```bash
gcloud iam service-accounts add-iam-policy-binding \
  <GSA>@<GSA_PROJECT_ID>.iam.gserviceaccount.com \
  --role roles/iam.workloadIdentityUser \
  --member "<FEDERATED_PRINCIPALSET>"
```

`roles/iam.workloadIdentityUser` is the least-privilege role for letting an
external principal impersonate a service account: it grants
`iam.serviceAccounts.getAccessToken` (what the gateway calls) and nothing more.
`roles/iam.serviceAccountTokenCreator` also works but is broader — it additionally
permits blob/JWT signing — so prefer `workloadIdentityUser`. See Google's
[WIF best practices](https://cloud.google.com/iam/docs/best-practices-for-using-workload-identity-federation).

Impersonation is usually preferable for enterprises: a named, single-purpose,
revocable identity whose Vertex grant lives on the service account (grantable
across many model projects), rather than binding an external principal into each
project's IAM. Scope the grant to the specific federated principal, not the whole
cloud account.

## Step 3: Enable Workload Auth on the Gateway

```yaml
environment:
  data:
    GCP_AUTH_MODE: workload
    # Off GKE only — the federation audience (pool/provider):
    GCP_WIF_AUDIENCE: "//iam.googleapis.com/projects/<POOL_PROJECT_NUMBER>/locations/global/workloadIdentityPools/<POOL_ID>/providers/<PROVIDER_ID>"
    # Optional — set to impersonate the GSA; omit for direct resource access:
    GCP_WIF_SERVICE_ACCOUNT_EMAIL: "<GSA>@<GSA_PROJECT_ID>.iam.gserviceaccount.com"
```

| Variable | Effect |
|----------|--------|
| `GCP_AUTH_MODE=workload` | permits the workload-identity token path (required) |
| `GCP_WIF_AUDIENCE` | off-GKE federation audience; when unset the GKE metadata server is used |
| `GCP_WIF_SERVICE_ACCOUNT_EMAIL` | when set, the gateway impersonates this SA after federating; when empty it accesses Vertex directly. Gateway-wide (not per-request). |

The gateway builds its own credential — it does **not** read
`GOOGLE_APPLICATION_CREDENTIALS`. Changing `environment.data` rolls the gateway
pods.

## Step 4: Configure the Integration

On the Vertex AI integration (or Virtual Key) in the control plane, set the auth
type to `workload` and provide the Vertex project ID and region. Leave the service
account JSON field empty — if a JSON key is present it takes precedence and the
workload-identity path is skipped.

## Step 5: Verify

Send a request through the gateway routed at your Vertex integration:

```bash
curl https://<GATEWAY_HOST>/v1/chat/completions \
  -H "Content-Type: application/json" \
  -H "x-portkey-api-key: <API_KEY>" \
  -H "x-portkey-provider: @<INTEGRATION_SLUG>" \
  -d '{
    "model": "anthropic.claude-sonnet-4-5@20250929",
    "max_tokens": 64,
    "messages": [{"role": "user", "content": "hello"}]
  }'
```

## Additional configurations

### Multiple Vertex projects from one gateway

The Vertex project and region are per integration, so a single gateway can route
to several projects — one integration per project, each its own billing/quota
boundary. The gateway has a single federated identity (and, if used, a single
impersonation service account), so grant that identity `roles/aiplatform.user` on
each target project. Per-project *identity* isolation requires a separate gateway.

## Important Notes

- Both the integration auth type **and** `GCP_AUTH_MODE` must be set to
  `workload`. Setting only one produces an authentication error.
- `GCP_AUTH_MODE` is shared with the GCS log store. If you already set it for
  [Log Store](./LogStore.md) GCS access, Vertex uses the same value.
- Anthropic models on Vertex must be addressed with the publisher prefix, for
  example `anthropic.claude-sonnet-4-5@20250929`. Without the prefix the gateway
  resolves the request against `publishers/google` and Vertex returns a 404.
- `GCP_WIF_SERVICE_ACCOUNT_EMAIL` is read from the environment (gateway-wide); it
  cannot be varied per request.
- Changing `environment.data` rolls the gateway pods, since the values are
  rendered into the deployment.

## Troubleshooting

**`Request had invalid authentication credentials. Expected OAuth 2 access token, login cookie or other valid authentication credential.`**

The gateway sent no usable token. Check, in order:

1. `GCP_AUTH_MODE` is present in the running pod —
   `kubectl exec <pod> -- env | grep GCP_AUTH_MODE`. This is the most common
   cause: the integration is set to `workload`, but the variable was never added
   to `values.yaml`.
2. The integration's auth type is `workload` and its service account JSON field
   is empty.
3. On GKE, Workload Identity resolves from inside the pod:

   ```bash
   kubectl exec <pod> -- wget -qO- \
     --header "Metadata-Flavor: Google" \
     "http://metadata.google.internal/computeMetadata/v1/instance/service-accounts/default/email"
   ```

   This should print the GSA, not the node's default compute service account. If
   it prints the wrong identity, the KSA annotation or the
   `roles/iam.workloadIdentityUser` binding is wrong.
4. Off GKE, confirm `GCP_WIF_AUDIENCE` is set to the pool/provider audience and
   that the platform's native identity is allowed to federate (see below).

**`Publisher model ... was not found or your project does not have access to it`**

Authentication succeeded and the request reached Vertex. Either the model name is
missing its publisher prefix (see Important Notes), the model is not enabled in
the target project, or it is not served in the configured region.

**`Permission 'aiplatform.endpoints.predict' denied` (direct) or `Permission 'iam.serviceAccounts.getAccessToken' denied` (impersonation)**

Authentication resolved but the identity lacks a grant.

- **On GKE / direct access:** the GSA (or federated principal) is missing
  `roles/aiplatform.user` on the project that serves the model.
- **Impersonation:** the federated principal is missing
  `roles/iam.workloadIdentityUser` (or `roles/iam.serviceAccountTokenCreator`) on
  the GSA, or the GSA itself is missing `roles/aiplatform.user` on the model
  project. Also confirm the Service Account Credentials API
  (`iamcredentials.googleapis.com`) is enabled.
- **Off GKE**, if federation itself is failing, the problem is in the WIF
  pool/provider or attribute mapping — see Google's
  [Workload Identity Federation guide](https://cloud.google.com/iam/docs/workload-identity-federation-with-other-providers),
  not this doc.
