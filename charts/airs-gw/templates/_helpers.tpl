{{/*
Expand the name of the chart.
*/}}
{{- define "airsgateway.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
If release name contains chart name it will be used as a full name.
*/}}
{{- define "airsgateway.fullname" -}}
{{- if .Values.fullnameOverride }}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- $name := default .Chart.Name .Values.nameOverride }}
{{- if contains $name .Release.Name }}
{{- .Release.Name | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" }}
{{- end }}
{{- end }}
{{- end }}

{{/*
Create chart name and version as used by the chart label.
*/}}
{{- define "airsgateway.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
User-defined labels applied to every resource.
*/}}
{{- define "airsgateway.commonLabels" -}}
{{- with .Values.commonLabels }}
{{- toYaml . }}
{{- end }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "airsgateway.labels" -}}
helm.sh/chart: {{ include "airsgateway.chart" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- include "airsgateway.commonLabels" . }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "airsgateway.selectorLabels" -}}
app.kubernetes.io/name: {{ include "airsgateway.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- with .Values.selectorLabels }}
{{ toYaml . }}
{{- end }}
{{- end }}

{{/*
Gateway labels
*/}}
{{- define "gateway.labels" -}}
{{- include "airsgateway.labels" . | nindent 4 }}
{{- include "airsgateway.selectorLabels" . | nindent 4 }}
{{- end }}

{{/*
Data Service labels
*/}}
{{- define "dataservice.labels" -}}
{{- include "airsgateway.labels" . }}
{{- include "dataservice.selectorLabels" . }}
{{- end }}

{{/*
Data Service Selector labels
*/}}
{{- define "dataservice.selectorLabels" -}}
{{- if hasKey .Values.dataservice.deployment.selectorLabels "app.kubernetes.io/name" }}
app.kubernetes.io/name: {{ get .Values.dataservice.deployment.selectorLabels "app.kubernetes.io/name" }}
{{- else }}
app.kubernetes.io/name: {{ include "airsgateway.name" . }}
{{- end }}
{{- if hasKey .Values.dataservice.deployment.selectorLabels "app.kubernetes.io/instance" }}
app.kubernetes.io/instance: {{ get .Values.dataservice.deployment.selectorLabels "app.kubernetes.io/instance" }}
{{- else }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}
{{- if hasKey .Values.dataservice.deployment.selectorLabels "app.kubernetes.io/component" }}
app.kubernetes.io/component: {{ get .Values.dataservice.deployment.selectorLabels "app.kubernetes.io/component" }}
{{- else }}
app.kubernetes.io/component: {{ include "airsgateway.fullname" . }}-{{ .Values.dataservice.name }}
{{- end }}
{{- end }}

{{/*
Common annotations
*/}}
{{- define "airsgateway.annotations" -}}
{{- if .Values.commonAnnotations }}
{{ toYaml .Values.commonAnnotations }}
{{- end }}
helm.sh/chart: {{ include "airsgateway.chart" . }}
{{ include "airsgateway.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Create the name of the service account to use
*/}}
{{- define "airsgateway.serviceAccountName" -}}
{{- if .Values.serviceAccount.create }}
{{- default (include "airsgateway.fullname" .) .Values.serviceAccount.name }}
{{- else if not .Values.serviceAccount.name }}
{{- fail "serviceAccount.name must be set when serviceAccount.create is false" }}
{{- else }}
{{- .Values.serviceAccount.name }}
{{- end }}
{{- end }}

{{- define "dataservice.serviceAccountName" -}}
{{- if .Values.dataservice.serviceAccount.create -}}
{{ default (printf "%s-%s" (include "airsgateway.fullname" .) .Values.dataservice.name) .Values.dataservice.serviceAccount.name | trunc 63 | trimSuffix "-" }}
{{- else if not .Values.dataservice.serviceAccount.name -}}
{{- fail "dataservice.serviceAccount.name must be set when dataservice.serviceAccount.create is false" }}
{{- else -}}
{{ .Values.dataservice.serviceAccount.name | trunc 63 | trimSuffix "-" }}
{{- end -}}
{{- end -}}


{{/*
Merged imagePullSecrets from both .Values.imagePullSecrets and .Values.imageCredentials
*/}}
{{- define "airsgateway.imagePullSecrets" -}}
{{- $names := list -}}
{{- range .Values.imagePullSecrets -}}
  {{- $name := "" -}}
  {{- if kindIs "string" . -}}
    {{- $name = . -}}
  {{- else -}}
    {{- $name = .name -}}
  {{- end -}}
  {{- if and $name (not (has $name $names)) -}}
    {{- $names = append $names $name -}}
  {{- end -}}
{{- end -}}
{{- range .Values.imageCredentials -}}
  {{- if and .name (not (has .name $names)) -}}
    {{- $names = append $names .name -}}
  {{- end -}}
{{- end -}}
{{- if $names }}
imagePullSecrets:
{{- range $names }}
  - name: {{ . }}
{{- end }}
{{- end -}}
{{- end -}}

{{/*
Create the image pull credentials
Supports both username/password and direct auth token
*/}}
{{- define "imagePullSecret" }}
{{- with . }}
{{- if .auth }}
{{- printf "{\"auths\":{\"%s\":{\"auth\":\"%s\"}}}" .registry .auth | b64enc }}
{{- else }}
{{- printf "{\"auths\":{\"%s\":{\"username\":\"%s\",\"password\":\"%s\",\"email\":\"%s\",\"auth\":\"%s\"}}}" .registry .username .password .email (printf "%s:%s" .username .password | b64enc) | b64enc }}
{{- end }}
{{- end }}
{{- end }}

{{/*
Name of the secret containing the secrets for redis. This can be overridden by a secrets file created by
the user or some other secret provisioning mechanism
*/}}
{{- define "airsgateway.redisSecretsName" -}}
{{- if .Values.redis.external.existingSecretName }}
{{- .Values.redis.external.existingSecretName }}
{{- else }}
{{- include "airsgateway.fullname" . }}-{{ .Values.redis.name }}
{{- end }}
{{- end }}

{{- define "redis.serviceAccountName" -}}
{{- if .Values.redis.serviceAccount.create -}}
    {{ default (printf "%s-%s" (include "airsgateway.fullname" .) .Values.redis.name) .Values.redis.serviceAccount.name | trunc 63 | trimSuffix "-" }}
{{- else -}}
    {{ default "default" .Values.redis.serviceAccount.name }}
{{- end -}}
{{- end -}}

{{/*
Redis environment variables sourced from the redis secret (bundled or external).
*/}}
{{- define "airsgateway.redisEnv" -}}
- name: REDIS_URL
  valueFrom:
    secretKeyRef:
      name: {{ include "airsgateway.redisSecretsName" . }}
      key: redis_connection_url
- name: REDIS_TLS_ENABLED
  valueFrom:
    secretKeyRef:
      name: {{ include "airsgateway.redisSecretsName" . }}
      key: redis_tls_enabled
- name: REDIS_MODE
  valueFrom:
    secretKeyRef:
      name: {{ include "airsgateway.redisSecretsName" . }}
      key: redis_mode
- name: CACHE_STORE
  valueFrom:
    secretKeyRef:
      name: {{ include "airsgateway.redisSecretsName" . }}
      key: redis_store
{{- end }}

{{/*
Vault Annotations
*/}}
{{- define "airsgateway.vaultAnnotations" -}}
{{.Values.vaultConfig.vaultHost}}/agent-inject: "true"
{{.Values.vaultConfig.vaultHost}}/agent-inject-secret-{{ .Chart.Name }}: {{ .Values.vaultConfig.secretPath | quote }}
{{.Values.vaultConfig.vaultHost}}/role: {{ .Values.vaultConfig.role | quote }}
{{- end }}

{{/*
Vault Environment Variables
*/}}
{{- define "airsgateway.vaultEnv" -}}
{{- $secretFile := .Values.vaultConfig.kubernetesSecret | default .Chart.Name }}
{{- range $key, $value := .Values.environment.data }}
- name: {{ $key }}
  valueFrom:
    secretKeyRef:
      name: {{ $secretFile }}
      key: {{ $key }}
{{- end }}
{{- end }}

{{/*
Fail fast when required management-plane env vars are missing.
Skipped when useVaultInjection is true, or when the key is supplied via
environment.existingSecret (listed in secretKeys, or lookup mode with no secretKeys).
*/}}
{{- define "airsgateway.validateRequiredEnv" -}}
{{- if not .Values.useVaultInjection }}
{{- $data := .Values.environment.data | default dict }}
{{- $secretKeys := .Values.environment.secretKeys | default list }}
{{- $viaExistingSecret := and (not .Values.environment.create) .Values.environment.existingSecret }}
{{- $authFromSecret := and $viaExistingSecret (or (empty $secretKeys) (has "PORTKEY_CLIENT_AUTH" $secretKeys)) }}
{{- if and (not $authFromSecret) (empty ((index $data "PORTKEY_CLIENT_AUTH") | default "" | toString | trim)) }}
{{- fail "environment.data.PORTKEY_CLIENT_AUTH must not be empty. Set it in values, or provide it via environment.existingSecret (include it in environment.secretKeys when using explicit mode)." }}
{{- end }}
{{- $orgsFromSecret := and $viaExistingSecret (or (empty $secretKeys) (has "ORGANISATIONS_TO_SYNC" $secretKeys)) }}
{{- if and (not $orgsFromSecret) (empty ((index $data "ORGANISATIONS_TO_SYNC") | default "" | toString | trim)) }}
{{- fail "environment.data.ORGANISATIONS_TO_SYNC must not be empty. Set it in values, or provide it via environment.existingSecret (include it in environment.secretKeys when using explicit mode)." }}
{{- end }}
{{- end }}
{{- end }}

{{/*
Common Environment Env
*/}}
{{- define "airsgateway.commonEnv" -}}
{{- include "airsgateway.validateRequiredEnv" . }}
{{- if .Values.useVaultInjection }}
{{- include "airsgateway.vaultEnv" . }}
{{- else }}
{{- if .Values.environment.create }}
{{- range $key, $value := .Values.environment.data }}
- name: {{ $key }}
  valueFrom:
    {{- if $.Values.environment.secret }}
    secretKeyRef:
    {{- else }}
    configMapKeyRef:
    {{- end }}
      name: {{ include "airsgateway.fullname" $ }}
      key: {{ $key }}
{{- end }}
{{- else if .Values.environment.existingSecret }}
{{- if .Values.environment.secretKeys }}
{{- range .Values.environment.secretKeys }}
- name: {{ . }}
  valueFrom:
    secretKeyRef:
      name: {{ $.Values.environment.existingSecret }}
      key: {{ . }}
{{- end }}
{{- range $key, $value := .Values.environment.data }}
{{- if not (has $key $.Values.environment.secretKeys) }}
- name: {{ $key }}
  value: {{ $value | quote }}
{{- end }}
{{- end }}
{{- else }}
{{- $secret := lookup "v1" "Secret" .Release.Namespace .Values.environment.existingSecret }}
{{- range $key, $value := .Values.environment.data }}
{{- if and $secret (hasKey $secret.data $key) }}
- name: {{ $key }}
  valueFrom:
    secretKeyRef:
      name: {{ $.Values.environment.existingSecret }}
      key: {{ $key }}
{{- else }}
- name: {{ $key }}
  value: {{ $value | quote }}
{{- end }}
{{- end }}
{{- end }}
{{- end }}
{{- end }}
{{- end }}

{{/*
Built-in defaults rendered only when not already provided in environment.data.
*/}}
{{- define "airsgateway.builtinDefaults" -}}
{{- $env := include "airsgateway.commonEnvMap" . | fromYaml -}}
{{- $defaults := dict
  "ALBUS_BASEPATH"           "https://mp.us.prod.airs-gw.portkey.ai"
  "CONTROL_PLANE_BASEPATH"   "https://aigw.portkey.ai/v1"
  "CONFIG_READER_PATH"       "https://api.portkey.ai/v1/sync/model-configs"
-}}
{{- range $key, $val := $defaults }}
{{- if not (hasKey $env $key) }}
{{- include "airsgateway.renderEnvVar" (list $key $val) | nindent 0 }}
{{- end }}
{{- end }}
{{- end }}

{{/*
Common Environment Env as Map
*/}}
{{- define "airsgateway.commonEnvMap" -}}
{{- $envMap := dict -}}
{{- if .Values.useVaultInjection }}
  {{- $secretFile := .Values.vaultConfig.kubernetesSecret | default .Chart.Name }}
  {{- range $key, $value := .Values.environment.data }}
    {{- $envValue := dict "valueFrom" (dict "secretKeyRef" (dict "name" $secretFile "key" $key)) }}
    {{- $_ := set $envMap $key $envValue }}
  {{- end }}
{{- else if .Values.environment.create }}
  {{- range $key, $value := .Values.environment.data }}
    {{- $envValue := dict -}}
    {{- if $.Values.environment.secret }}
      {{- $_ := set $envValue "valueFrom" (dict "secretKeyRef" (dict "name" (include "airsgateway.fullname" $) "key" $key)) -}}
    {{- else }}
      {{- $_ := set $envValue "valueFrom" (dict "configMapKeyRef" (dict "name" (include "airsgateway.fullname" $) "key" $key)) -}}
    {{- end }}
    {{- $_ := set $envMap $key $envValue -}}
  {{- end }}
{{- else if .Values.environment.existingSecret }}
  {{- /* Auto-detect mode based on presence of secretKeys */}}
  {{- if .Values.environment.secretKeys }}
    {{- /* EXPLICIT MODE: secretKeys provided */}}
    {{- range .Values.environment.secretKeys }}
      {{- $envValue := dict "valueFrom" (dict "secretKeyRef" (dict "name" $.Values.environment.existingSecret "key" .)) }}
      {{- $_ := set $envMap . $envValue }}
    {{- end }}
    {{- /* Add non-secret data values (skip keys that are in secretKeys) */}}
    {{- range $key, $value := .Values.environment.data }}
      {{- if not (has $key $.Values.environment.secretKeys) }}
        {{- $envValue := dict "value" ($value | toString) }}
        {{- $_ := set $envMap $key $envValue }}
      {{- end }}
    {{- end }}
  {{- else }}
    {{- /* AUTO MODE : No secretKeys provided, use lookup with fallback */}}
    {{- $secret := lookup "v1" "Secret" .Release.Namespace .Values.environment.existingSecret }}
    {{- range $key, $value := .Values.environment.data }}
      {{- if and $secret (hasKey $secret.data $key) }}
        {{- $envValue := dict "valueFrom" (dict "secretKeyRef" (dict "name" $.Values.environment.existingSecret "key" $key)) }}
        {{- $_ := set $envMap $key $envValue }}
      {{- else }}
        {{- $envValue := dict "value" ($value | toString) }}
        {{- $_ := set $envMap $key $envValue }}
      {{- end }}
    {{- end }}
  {{- end }}
{{- end }}
{{- $envMap | toYaml -}}
{{- end }}

{{- define "airsgateway.renderEnvVar" -}}
{{- $name := index . 0 -}}
{{- $value := index . 1 -}}
- name: {{ $name }}
{{- if kindIs "map" $value }}
  {{- toYaml $value | nindent 2 }}
{{- else }}
  value: {{ $value | quote }}
{{- end }}
{{- end }}

{{- define "logStore.commonEnv" -}}
{{- $commonEnv := include "airsgateway.commonEnvMap" . | fromYaml -}}
{{- range $key, $value := $commonEnv }}
{{- if has $key (list "LOG_STORE" "LOG_STORE_ACCESS_KEY" "LOG_STORE_SECRET_KEY" "LOG_STORE_REGION" "LOG_STORE_GENERATIONS_BUCKET" "LOG_STORE_BASEPATH" "LOG_STORE_AWS_ROLE_ARN" "LOG_STORE_AWS_EXTERNAL_ID" "AZURE_AUTH_MODE" "AZURE_STORAGE_ACCOUNT" "AZURE_STORAGE_KEY" "AZURE_STORAGE_CONTAINER" "AZURE_MANAGED_CLIENT_ID" "AZURE_ENTRA_CLIENT_ID" "AZURE_ENTRA_CLIENT_SECRET" "AZURE_ENTRA_TENANT_ID") }}
{{- include "airsgateway.renderEnvVar" (list $key $value) | nindent 0 }}
{{- end }}
{{- end }}
{{- end }}

{{- define "analyticStore.commonEnv" -}}
{{- $commonEnv := include "airsgateway.commonEnvMap" . | fromYaml -}}
{{- include "airsgateway.renderEnvVar" (list "ANALYTICS_STORE" "control_plane") | nindent 0 }}
{{- range $key, $value := $commonEnv }}
{{- if has $key (list "ANALYTICS_STORE_ENDPOINT" "ANALYTICS_STORE_USER" "ANALYTICS_STORE_PASSWORD" "ANALYTICS_LOG_TABLE" "ANALYTICS_FEEDBACK_TABLE") }}
{{- include "airsgateway.renderEnvVar" (list $key $value) | nindent 0 }}
{{- end }}
{{- end }}
{{- end }}

{{- define "cacheStore.commonEnv" -}}
{{- $commonEnv := include "airsgateway.commonEnvMap" . | fromYaml -}}
{{- range $key, $value := $commonEnv }}
{{- if has $key (list "CACHE_STORE" "REDIS_URL" "REDIS_PORT" "REDIS_HOST" "REDIS_TLS_ENABLED" "REDIS_MODE" "REDIS_TLS_CERTS" "REDIS_USERNAME" "REDIS_PASSWORD" "REDIS_SCALE_READS" "REDIS_CLUSTER_ENDPOINTS" "REDIS_CLUSTER_DISCOVERY_URL" "REDIS_CLUSTER_DISCOVERY_AUTH" "AZURE_REDIS_AUTH_MODE" "AZURE_REDIS_ENTRA_CLIENT_ID" "AZURE_REDIS_ENTRA_CLIENT_SECRET" "AZURE_REDIS_ENTRA_TENANT_ID" "AZURE_REDIS_MANAGED_CLIENT_ID" "AWS_REDIS_AUTH_MODE" "AWS_REDIS_CLUSTER_NAME" "AWS_REDIS_REGION" "AWS_REDIS_ASSUME_ROLE_ARN" "AWS_REDIS_ROLE_EXTERNAL_ID") }}
{{- include "airsgateway.renderEnvVar" (list $key $value) | nindent 0 }}
{{- end }}
{{- end }}
{{- end }}

{{- define "managementPlane.commonEnv" -}}
{{- include "airsgateway.validateRequiredEnv" . }}
{{- $commonEnv := include "airsgateway.commonEnvMap" . | fromYaml -}}
{{- range $key, $value := $commonEnv }}
{{- if has $key (list "PORTKEY_CLIENT_AUTH" "ORGANISATIONS_TO_SYNC") }}
{{- include "airsgateway.renderEnvVar" (list $key $value) | nindent 0 }}
{{- end }}
{{- end }}
{{- end }}

{{- define "dataservice.commonEnv" -}}
{{- include "airsgateway.renderEnvVar" (list "PORT" .Values.dataservice.containerPort) | nindent 0 }}
{{- $commonEnv := include "airsgateway.commonEnvMap" . | fromYaml -}}
{{- if hasKey $commonEnv "ALBUS_BASEPATH" -}}
{{- include "airsgateway.renderEnvVar" (list "ALBUS_ENDPOINT" $commonEnv.ALBUS_BASEPATH) | nindent 0 }}
{{- else -}}
{{- include "airsgateway.renderEnvVar" (list "ALBUS_ENDPOINT" "https://albus.portkey.ai") | nindent 0 }}
{{- end -}}
{{- include "airsgateway.renderEnvVar" (list "NODE_ENV" "production") | nindent 0 }}
{{- include "airsgateway.renderEnvVar" (list "HYBRID_DEPLOYMENT" "ON") | nindent 0 }}
{{- if .Values.dataservice.env.DEBUG_ENABLED }}
{{- include "airsgateway.renderEnvVar" (list "NODE_DEBUG" "dataservice:*") | nindent 0 }}
{{- end }}
{{- include "airsgateway.renderEnvVar" (list "SERVICE_NAME" .Values.dataservice.env.SERVICE_NAME) | nindent 0 }}
{{- range $key, $value := $commonEnv }}
{{- if has $key (list "ANALYTICS_STORE" "ANALYTICS_STORE_ENDPOINT" "ANALYTICS_STORE_USER" "ANALYTICS_STORE_PASSWORD" "ANALYTICS_LOG_TABLE") }}
{{- include "airsgateway.renderEnvVar" (list $key $value) | nindent 0 }}
{{- end }}
{{- end }}
{{- include "airsgateway.renderEnvVar" (list "CLICKHOUSE_HOST" ($commonEnv.ANALYTICS_STORE_ENDPOINT)) | nindent 0 }}
{{- include "airsgateway.renderEnvVar" (list "CLICKHOUSE_USER" ($commonEnv.ANALYTICS_STORE_USER)) | nindent 0 }}
{{- include "airsgateway.renderEnvVar" (list "CLICKHOUSE_PASSWORD" ($commonEnv.ANALYTICS_STORE_PASSWORD)) | nindent 0 }}
{{- end }}

{{/*
mcp.serverMode
→ Returns string
*/}}
{{- define "mcp.serverMode" -}}
{{- $env := (include "airsgateway.commonEnvMap" . | fromYaml) -}}
{{- $serverMode := "" -}}
{{- if hasKey $env "SERVER_MODE" -}}
  {{- $entry := index $env "SERVER_MODE" -}}
  {{- if hasKey $entry "value" -}}
    {{- $serverMode = (index $entry "value") | toString -}}
  {{- else -}}
    {{- $serverMode = (index .Values.environment.data "SERVER_MODE") | default "" | toString -}}
  {{- end -}}
{{- else -}}
  {{- $serverMode = (index .Values.environment.data "SERVER_MODE") | default "" | toString -}}
{{- end -}}
{{- $serverMode | trim | toString -}}
{{- end -}}

{{/*
mcp.enabled
→ Returns boolean
*/}}
{{- define "mcp.enabled" -}}
{{- $serverMode := include "mcp.serverMode" . -}}
{{- if or (eq $serverMode "all") (eq $serverMode "mcp") -}}
{{- true -}}
{{- else -}}
{{- false -}}
{{- end -}}
{{- end -}}

{{/*
gateway.enabled
→ Returns true when SERVER_MODE is empty/missing or "all"
→ Returns false for any other value
*/}}
{{- define "gateway.enabled" -}}
{{- $serverMode := include "mcp.serverMode" . -}}
{{- if or (eq $serverMode "") (eq $serverMode "all") -}}
{{- true -}}
{{- else -}}
{{- false -}}
{{- end -}}
{{- end -}}

{{/*
mcp.containerPort
→ Returns integer port
Priority: mcpService.containerPort > MCP_PORT env > 8788 default
*/}}
{{- define "mcp.containerPort" -}}
{{- if and .Values.mcpService .Values.mcpService.enabled .Values.mcpService.containerPort -}}
{{- .Values.mcpService.containerPort | int -}}
{{- else -}}
{{- $env := (include "airsgateway.commonEnvMap" . | fromYaml) -}}
{{- $port := "" -}}
{{- if hasKey $env "MCP_PORT" -}}
  {{- $entry := index $env "MCP_PORT" -}}
  {{- if hasKey $entry "value" -}}
    {{- $port = (index $entry "value") | toString -}}
  {{- else -}}
    {{- $port = (index .Values.environment.data "MCP_PORT") | default "" | toString -}}
  {{- end -}}
{{- else -}}
  {{- $port = (index .Values.environment.data "MCP_PORT") | default "" | toString -}}
{{- end -}}
{{- if eq $port "" -}}
8788
{{- else -}}
{{- $port | int -}}
{{- end -}}
{{- end -}}
{{- end -}}

{{/*
gateway.containerPort
→ Returns integer port for gateway
*/}}
{{- define "gateway.containerPort" -}}
{{- if .Values.service.containerPort -}}
{{- .Values.service.containerPort | int -}}
{{- else -}}
{{- $env := (include "airsgateway.commonEnvMap" . | fromYaml) -}}
{{- $port := "" -}}
{{- if hasKey $env "PORT" -}}
  {{- $entry := index $env "PORT" -}}
  {{- if hasKey $entry "value" -}}
    {{- $port = (index $entry "value") | toString -}}
  {{- else -}}
    {{- $port = (index .Values.environment.data "PORT") | default "" | toString -}}
  {{- end -}}
{{- else -}}
  {{- $port = (index .Values.environment.data "PORT") | default "" | toString -}}
{{- end -}}
{{- if eq $port "" -}}
{{- .Values.service.port | default 8787 | int -}}
{{- else -}}
{{- $port | int -}}
{{- end -}}
{{- end -}}
{{- end -}}

{{/*
gateway.primaryPort
→ Returns the port the running server listens on.
Gateway port when gateway is enabled, otherwise the MCP port.
*/}}
{{- define "gateway.primaryPort" -}}
{{- if eq (include "gateway.enabled" .) "true" -}}
{{- include "gateway.containerPort" . -}}
{{- else -}}
{{- include "mcp.containerPort" . -}}
{{- end -}}
{{- end -}}

{{/*
Milvus etcd labels
*/}}
{{- define "milvus-etcd.labels" -}}
helm.sh/chart: {{ include "airsgateway.chart" . }}
{{ include "milvus-etcd.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- include "airsgateway.commonLabels" . }}
{{- end }}

{{/*
Milvus etcd selector labels
*/}}
{{- define "milvus-etcd.selectorLabels" -}}
app.kubernetes.io/name: milvus-etcd
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/component: milvus-etcd
{{- end }}

{{/*
MinIO labels
*/}}
{{- define "minio.labels" -}}
helm.sh/chart: {{ include "airsgateway.chart" . }}
{{ include "minio.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- include "airsgateway.commonLabels" . }}
{{- end }}

{{/*
MinIO selector labels
*/}}
{{- define "minio.selectorLabels" -}}
app.kubernetes.io/name: minio
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/component: minio
{{- end }}

{{/*
Validate MinIO auth key configuration.
- Fails fast if both minio.authKey.create and minio.authKey.existingSecret are set,
  since the chart can either create the Secret or consume an existing one, not both.
- Fails fast if neither is configured (create=false and no existingSecret), since the
  chart would reference a Secret that is never created, causing a runtime failure.
- Validates accessKey/secretKey only when the chart is actually creating the Secret
  (create=true and no existingSecret).
Only enforced when MinIO is enabled.
*/}}
{{- define "minio.validateAuthKey" -}}
{{- if .Values.minio.enabled }}
{{- if and .Values.minio.authKey.create .Values.minio.authKey.existingSecret }}
{{- fail "minio.authKey.create and minio.authKey.existingSecret are mutually exclusive. Set create=true to have the chart create the Secret, or provide existingSecret (with create=false) to use your own." }}
{{- end }}
{{- if and (not .Values.minio.authKey.create) (not .Values.minio.authKey.existingSecret) }}
{{- fail "No MinIO credentials source configured. Set minio.authKey.create=true (with accessKey/secretKey) to have the chart create the Secret, or set minio.authKey.existingSecret to use an existing one. Otherwise MinIO references a Secret that is never created." }}
{{- end }}
{{- if .Values.minio.authKey.create }}
{{- if not .Values.minio.authKey.accessKey }}
{{- fail "minio.authKey.accessKey must not be empty when minio.authKey.create is true. Set it, or provide credentials via minio.authKey.existingSecret (with create=false)." }}
{{- end }}
{{- if not .Values.minio.authKey.secretKey }}
{{- fail "minio.authKey.secretKey must not be empty when minio.authKey.create is true. Set it, or provide credentials via minio.authKey.existingSecret (with create=false)." }}
{{- end }}
{{- end }}
{{- end }}
{{- end }}

{{/*
MinIO auth key secret name
*/}}
{{- define "minio.secretName" -}}
{{- include "minio.validateAuthKey" . -}}
{{- if .Values.minio.authKey.existingSecret -}}
{{- .Values.minio.authKey.existingSecret -}}
{{- else -}}
minio-secret
{{- end -}}
{{- end }}

{{/*
Milvus labels
*/}}
{{- define "milvus.labels" -}}
helm.sh/chart: {{ include "airsgateway.chart" . }}
{{ include "milvus.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- include "airsgateway.commonLabels" . }}
{{- end }}

{{/*
Milvus selector labels
*/}}
{{- define "milvus.selectorLabels" -}}
app.kubernetes.io/name: milvus
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/component: milvus
{{- end }}