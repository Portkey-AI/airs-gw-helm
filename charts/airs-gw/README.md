# AIRS Gateway Helm Chart

## Prerequisites

[Helm](https://helm.sh) must be installed to use the charts. Please refer to Helm's [documentation](https://helm.sh/docs) to get started.

## Quick Start

### 1. Register your Gateway

Follow the [Gateway Registration guide](https://docs.portkey.ai/docs/self-hosting/hybrid-deployments/gateway-registration) to register your gateway and download the pre-filled `values.yaml` configuration file.

### 2. Configure Storage

Update your `values.yaml` with the appropriate storage backends:

- **Log Store** — See [Log Store Configuration](./docs/LogStore.md) for AWS S3, Azure Blob Storage, GCS, and S3-compatible options
- **Cache Store** — See [Redis Configuration](./docs/CacheStore.md) for AWS ElastiCache, Azure Managed Redis, GCP Memorystore, and in-cluster Redis
- **Vector Store** *(Optional)* — See [Vector Store Setup](./docs/VectorStore.md) for semantic caching with Milvus
- **OTEL** *(Optional)* — See [OTEL Configuration](#otel-opentelemetry) to push analytics to OpenTelemetry-compatible endpoints

### 3. Deploy

```bash
helm repo add airs-gw https://portkey-ai.github.io/airs-gw-helm
helm repo update
helm upgrade --install airs-gw airs-gw/airs-gw \
  -f ./values.yaml \
  -n airs-gw \
  --create-namespace
```

### 4. Verify

```bash
kubectl get pods -n airs-gw
```

### 5. Test (Optional)

```bash
kubectl port-forward <pod-name> -n airs-gw 8787:8787
```

### 6. Configure Provider Authentication (Optional)

Providers that authenticate with cloud IAM rather than a static key need setup
on both the integration and the gateway deployment:

- **AWS Bedrock** — See [Bedrock Assumed Role Configuration](./docs/Bedrock.md)
- **Google Vertex AI** — See [Vertex AI Workload Identity](./docs/VertexAI.md)

---

## Exposing the Gateway

The chart exposes two endpoints: the **gateway** (`service.port`, default `8787`) and
the **MCP server** (`MCP_PORT`, default `8788`). Which of them get routed follows
`environment.data.SERVER_MODE` — `all` routes both, `""` the gateway only, `mcp` the
MCP server only.

Either an **Ingress** or the **Gateway API** can front them, and both support the same
two routing layouts:

| Layout | Values | Result |
|---|---|---|
| Path-based *(default)* | `hostBased: false` | One hostname — gateway on `gatewayPath` (`/`), MCP on `mcpPath` (`/mcp`) |
| Host-based | `hostBased: true` | Separate hostnames — `hostname` for the gateway, `mcpHostname` (defaults to `mcp.{hostname}`) for MCP |

### Ingress

```yaml
ingress:
  enabled: true
  hostname: airs-gw.example.com
  ingressClassName: nginx
  tls:
    - hosts:
        - airs-gw.example.com
      secretName: airs-gw-tls
```

### Gateway API

Requires the [Gateway API](https://gateway-api.sigs.k8s.io/) CRDs and a controller
(Istio, Envoy Gateway, NGINX Gateway Fabric, GKE Gateway, Kong, ...) installed in the
cluster. Renders a `Gateway` plus one `HTTPRoute` per enabled endpoint — named after
the release, with the MCP route suffixed `-mcp`.

```yaml
gatewayApi:
  enabled: true
  hostname: airs-gw.example.com
  gateway:
    gatewayClassName: envoy-gateway
    listener:
      name: https
      port: 443
      protocol: HTTPS
      tls:
        certificateRefs:
          - name: airs-gw-tls
```

To attach the routes to a `Gateway` owned by another team instead of creating one:

```yaml
gatewayApi:
  enabled: true
  hostname: airs-gw.example.com
  gateway:
    create: false
  httpRoute:
    parentRefs:
      - name: shared-gateway
        namespace: infra
        sectionName: https
```

On older Gateway API installs, set `gatewayApi.apiVersion: gateway.networking.k8s.io/v1beta1`.

See [Ingress Configuration](./docs/Configuration.md#ingress-configuration) and
[Gateway API Configuration](./docs/Configuration.md#gateway-api-configuration) for the
full value reference.

## Data Service (Optional)

Enable data service for 

- Custom fine-tuning 
- Custom batches
- Data exports

```yaml
dataservice:
  enabled: true
```

**Note**: Currently only S3 is supported for fine-tuning data storage.

For detailed fine-tuning information, see [DataService.md](./docs/DataService.md).

---

## Uninstallation

```bash
helm uninstall airs-gw --namespace airs-gw
```

---

## References

- Helm repository: `https://portkey-ai.github.io/airs-gw-helm`
- [Artifact Hub (Portkey AI)](https://artifacthub.io/packages/search?org=portkey-ai&sort=relevance&page=1)
- [External Redis / Cache Store configuration](./docs/Redis.md) — configure AWS ElastiCache, Azure Managed Redis, or GCP Memorystore as the cache store
- [Ingress and Gateway API configuration](./docs/Configuration.md#ingress-configuration) — expose the gateway and MCP endpoints via Ingress or Gateway API
- [All available configuration options](./docs/Configuration.md) — full reference for all Helm chart values
- [Deployment guide](https://portkey.ai/docs/self-hosting/hybrid-deployments) — end-to-end steps for deploying on EKS, AKS, or GKE

---

## Support

- Review logs: `kubectl logs -n airs-gw deployment/airs-gw`

