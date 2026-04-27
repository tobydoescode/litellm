#!/usr/bin/env bash
set -euo pipefail

IMAGE="${LITELLM_SMOKE_IMAGE:-litellm:smoke}"
PORT="${LITELLM_SMOKE_PORT:-14000}"
POSTGRES_IMAGE="${LITELLM_SMOKE_POSTGRES_IMAGE:-postgres:16-alpine}"

RUN_ID="$(date +%s)-$$"
NETWORK="litellm-smoke-${RUN_ID}"
DB_CONTAINER="litellm-smoke-db-${RUN_ID}"
APP_CONTAINER="litellm-smoke-app-${RUN_ID}"
CONFIG_FILE=""

log() {
  printf '[smoke] %s\n' "$*"
}

dump_diagnostics() {
  log "Docker container status"
  docker ps -a --filter "name=${DB_CONTAINER}" --filter "name=${APP_CONTAINER}" || true

  if docker ps -a --format '{{.Names}}' | grep -qx "${DB_CONTAINER}"; then
    log "Postgres logs"
    docker logs "${DB_CONTAINER}" || true
  fi

  if docker ps -a --format '{{.Names}}' | grep -qx "${APP_CONTAINER}"; then
    log "LiteLLM logs"
    docker logs "${APP_CONTAINER}" || true
  fi
}

cleanup() {
  status=$?
  if [[ $status -ne 0 ]]; then
    dump_diagnostics
  fi

  docker rm -f "${APP_CONTAINER}" >/dev/null 2>&1 || true
  docker rm -f "${DB_CONTAINER}" >/dev/null 2>&1 || true
  docker network rm "${NETWORK}" >/dev/null 2>&1 || true

  if [[ -n "${CONFIG_FILE}" && -f "${CONFIG_FILE}" ]]; then
    rm -f "${CONFIG_FILE}"
  fi

  exit "$status"
}
trap cleanup EXIT

require_command() {
  if ! command -v "$1" >/dev/null 2>&1; then
    log "Required command not found: $1"
    exit 1
  fi
}

wait_for_postgres() {
  log "Waiting for Postgres readiness"
  for _ in $(seq 1 60); do
    if docker exec "${DB_CONTAINER}" pg_isready -U litellm -d litellm >/dev/null 2>&1; then
      log "Postgres is ready"
      return 0
    fi
    sleep 1
  done

  log "Postgres did not become ready"
  return 1
}

wait_for_http() {
  local url="$1"
  local want="$2"

  log "Waiting for ${url} to return ${want}"
  for _ in $(seq 1 90); do
    status="$(curl -fsS -o /tmp/litellm-smoke-response.txt -w '%{http_code}' "${url}" 2>/tmp/litellm-smoke-curl.txt || true)"
    if [[ "${status}" == "${want}" ]]; then
      log "${url} returned ${want}"
      return 0
    fi

    if ! docker ps --format '{{.Names}}' | grep -qx "${APP_CONTAINER}"; then
      log "LiteLLM container exited before HTTP readiness"
      return 1
    fi

    sleep 1
  done

  log "${url} did not return ${want}"
  log "Last curl stderr:"
  cat /tmp/litellm-smoke-curl.txt || true
  log "Last response body:"
  cat /tmp/litellm-smoke-response.txt || true
  return 1
}

assert_no_litellm_log_errors() {
  logs="$(docker logs "${APP_CONTAINER}" 2>&1 || true)"
  if grep -Eiq 'prisma db error|P1001|Can.t reach database server|Database migration failed|Application startup failed|ConnectError|connection refused|failed to start prisma|schema.prisma.*not found' <<< "${logs}"; then
    log "LiteLLM logs contain a Prisma/database failure"
    printf '%s\n' "${logs}"
    return 1
  fi
}

assert_prisma_tables_exist() {
  log "Checking for LiteLLM Prisma tables"
  table_count="$(
    docker exec "${DB_CONTAINER}" psql -U litellm -d litellm -Atc \
      "select count(*) from information_schema.tables where table_schema = 'public' and table_name like 'LiteLLM_%';"
  )"

  if [[ "${table_count}" =~ ^[0-9]+$ ]] && (( table_count > 0 )); then
    log "Found ${table_count} LiteLLM Prisma tables"
    docker exec "${DB_CONTAINER}" psql -U litellm -d litellm -Atc \
      "select table_name from information_schema.tables where table_schema = 'public' and table_name like 'LiteLLM_%' order by table_name limit 20;"
    return 0
  fi

  log "Expected at least one LiteLLM_% table, found: ${table_count}"
  docker exec "${DB_CONTAINER}" psql -U litellm -d litellm -Atc \
    "select table_schema || '.' || table_name from information_schema.tables where table_schema = 'public' order by table_name;" || true
  return 1
}

require_command docker
require_command curl

log "Smoke image: ${IMAGE}"
docker image inspect "${IMAGE}" >/dev/null

log "Creating Docker network ${NETWORK}"
docker network create "${NETWORK}" >/dev/null

log "Starting Postgres fixture"
docker run -d \
  --name "${DB_CONTAINER}" \
  --network "${NETWORK}" \
  --network-alias litellm-smoke-db \
  -e POSTGRES_DB=litellm \
  -e POSTGRES_USER=litellm \
  -e POSTGRES_PASSWORD=litellm \
  "${POSTGRES_IMAGE}" >/dev/null

wait_for_postgres

CONFIG_FILE="$(mktemp)"
cat > "${CONFIG_FILE}" <<'YAML'
model_list:
  - model_name: smoke-fake
    litellm_params:
      model: openai/smoke-fake
      api_key: os.environ/OPENAI_API_KEY
general_settings:
  master_key: os.environ/LITELLM_MASTER_KEY
  database_url: os.environ/DATABASE_URL
YAML

log "Starting LiteLLM candidate image"
docker run -d \
  --name "${APP_CONTAINER}" \
  --network "${NETWORK}" \
  -p "127.0.0.1:${PORT}:4000" \
  -e DATABASE_URL='postgresql://litellm:litellm@litellm-smoke-db:5432/litellm' \
  -e STORE_MODEL_IN_DB=True \
  -e LITELLM_MASTER_KEY=sk-smoke-master-key \
  -e OPENAI_API_KEY=sk-smoke-unused \
  -e LITELLM_LOG=INFO \
  -v "${CONFIG_FILE}:/tmp/litellm-smoke-config.yaml:ro" \
  --network-alias litellm-smoke-app \
  "${IMAGE}" \
  --config /tmp/litellm-smoke-config.yaml \
  --host 0.0.0.0 \
  --port 4000 >/dev/null

wait_for_http "http://127.0.0.1:${PORT}/health/liveliness" "200"
assert_no_litellm_log_errors
assert_prisma_tables_exist

log "LiteLLM image smoke test passed"
