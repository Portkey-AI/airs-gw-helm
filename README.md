# AIRS Gateway Helm Charts

Deploy AIRS Gateway (hybrid) via **Helm** or **Docker Compose**.

## Helm (Kubernetes)

```bash
helm repo add airs-gw https://portkey-ai.github.io/airs-gw-helm
helm repo update
helm upgrade --install airs-gw airs-gw/airs-gw \
  -f ./values.yaml \
  -n airs-gw \
  --create-namespace
```

Charts are also listed on [Artifact Hub](https://artifacthub.io/packages/search?org=portkey-ai&sort=relevance&page=1) under Portkey AI.

For full Helm chart documentation see [charts/airs-gw/README.md](./charts/airs-gw/README.md).

## Docker Compose

If you don't have Kubernetes, you can run the gateway with Docker Compose.

> **Minimum version**: `gateway_enterprise:2.15.0`

Create a `.env` file with your registration credentials (never commit real values):

```env
PORTKEY_CLIENT_AUTH=<your-client-auth>
ORGANISATIONS_TO_SYNC=<your-org-ids>
```

Then use the following `docker-compose.yml`:

```yaml
services:
  redis:
    image: redis:7.2.14-alpine@sha256:dfa18828cbc07b3ae6a95ec7343f6c214fdee2d836197b4be8e9904420762cd8
    container_name: ai-gateway-redis
    restart: unless-stopped
    volumes:
      - ./data:/data
    healthcheck:
      test: ["CMD", "redis-cli", "ping"]
      interval: 10s
      timeout: 3s
      retries: 6

  gateway:
    image: registry.portkey.ai/airsgw/gateway_enterprise:2.15.0@sha256:93ce67acfd916e9fa7ec31f790b598399f5686b41244cfdb6e8940ae1f2de759
    container_name: ai-gateway
    restart: unless-stopped
    depends_on:
      redis:
        condition: service_healthy
    ports:
      - "8787:8787"   # gateway API
      - "8788:8788"   # MCP server
    environment:
      SERVICE_NAME: airsgateway
      PORT: "8787"
      MCP_PORT: "8788"
      SERVER_MODE: "all"
      LOG_STORE_FILE_PATH_FORMAT: "v2"
      PORTKEY_CLIENT_AUTH: ${PORTKEY_CLIENT_AUTH}
      ORGANISATIONS_TO_SYNC: ${ORGANISATIONS_TO_SYNC}
      CACHE_STORE: "redis"
      REDIS_URL: "redis://redis:6379"
      REDIS_TLS_ENABLED: "false"
      REDIS_MODE: "standalone"
      ALBUS_BASEPATH: "https://mp.us.prod.airs-gw.portkey.ai/api"
      CONTROL_PLANE_BASEPATH: "https://aigw.portkey.ai/v1"
      ANALYTICS_STORE: "control_plane"
      LOG_STORE: "control_plane"
```

Start it:

```bash
docker compose up -d
```

Verify:

```bash
curl http://localhost:8787/v1/health
```
