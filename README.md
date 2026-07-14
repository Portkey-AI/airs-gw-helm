# AIRS Gateway Helm Charts

Helm chart for deploying AIRS Gateway (hybrid).

## Install

```bash
helm repo add airs-gw https://portkey-ai.github.io/airs-gw-helm
helm repo update
helm upgrade --install airs-gw airs-gw/airs-gw \
  -f ./values.yaml \
  -n airs-gw \
  --create-namespace
```

Charts are also listed on [Artifact Hub](https://artifacthub.io/packages/search?org=portkey-ai&sort=relevance&page=1) under Portkey AI.

## AIRS Gateway

Complete set of instructions: [charts/airs-gw/README.md](./charts/airs-gw/README.md)
