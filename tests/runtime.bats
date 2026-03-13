#!/usr/bin/env bats
# Runtime tests — start a long-running container and exercise its behaviour.
#
# All tests require access to the Docker socket at /var/run/docker.sock so that
# docker-gen can watch the daemon and regenerate the haproxy config.  Tests are
# automatically skipped when the socket is not available (e.g. in restricted CI
# environments or when running inside a container without socket mount).
#
# The integration backend tests pull nginx:alpine to act as a backend service.
# Pre-pulling the image (docker pull nginx:alpine) will speed these tests up.

bats_require_minimum_version 1.5.0

IMAGE="${IMAGE_NAME:-pygmystack/haproxy:test}"
HAPROXY_CONTAINER="haproxy-bats-test"
BACKEND_AMAZEEIO="haproxy-bats-backend-amazeeio"
BACKEND_LAGOON="haproxy-bats-backend-lagoon"
DOCKER_SOCKET="/var/run/docker.sock"
TEST_PORT="18080"

# ---------------------------------------------------------------------------
# File-level setup / teardown — container is started once for the entire file.
# ---------------------------------------------------------------------------

setup_file() {
    if [ ! -S "${DOCKER_SOCKET}" ]; then
        echo "# Docker socket not found at ${DOCKER_SOCKET} – skipping runtime tests" >&3
        return 0
    fi

    # Remove any leftover container from a previous (failed) run.
    docker rm -f "${HAPROXY_CONTAINER}" 2>/dev/null || true

    docker run -d \
        --name "${HAPROXY_CONTAINER}" \
        --volume "${DOCKER_SOCKET}:/tmp/docker.sock" \
        -p "${TEST_PORT}:80" \
        "${IMAGE}"

    # Wait for docker-gen to run once and reload haproxy with the stats frontend.
    # The template includes "stats uri /stats", so /stats becomes available only
    # after the first docker-gen pass — give it up to 30 seconds.
    local max_wait=30
    local waited=0
    until curl -sf "http://localhost:${TEST_PORT}/stats" >/dev/null 2>&1; do
        sleep 1
        waited=$((waited + 1))
        if [ "$waited" -ge "$max_wait" ]; then
            echo "# Timed out waiting for haproxy /stats endpoint" >&3
            docker logs "${HAPROXY_CONTAINER}" >&3 2>&3
            break
        fi
    done
}

teardown_file() {
    docker rm -f "${HAPROXY_CONTAINER}"     2>/dev/null || true
    docker rm -f "${BACKEND_AMAZEEIO}"      2>/dev/null || true
    docker rm -f "${BACKEND_LAGOON}"        2>/dev/null || true
}

# ---------------------------------------------------------------------------
# Helper — skip the current test when the Docker socket is absent.
# ---------------------------------------------------------------------------

_require_docker_socket() {
    if [ ! -S "${DOCKER_SOCKET}" ]; then
        skip "Docker socket not available at ${DOCKER_SOCKET}"
    fi
}

# ---------------------------------------------------------------------------
# Container lifecycle
# ---------------------------------------------------------------------------

@test "container is running" {
    _require_docker_socket
    run docker inspect --format='{{.State.Status}}' "${HAPROXY_CONTAINER}"
    [ "$status" -eq 0 ]
    [ "$output" = "running" ]
}

@test "haproxy process is alive (pidfile check)" {
    _require_docker_socket
    run docker exec "${HAPROXY_CONTAINER}" sh -c \
        'kill -0 "$(cat /var/run/haproxy.pid)" 2>/dev/null'
    [ "$status" -eq 0 ]
}

@test "docker-gen process is running inside the container" {
    _require_docker_socket
    run docker exec "${HAPROXY_CONTAINER}" sh -c \
        'ps aux 2>/dev/null | grep -c "[d]ocker-gen"'
    [ "$status" -eq 0 ]
    [ "$output" -ge 1 ]
}

# ---------------------------------------------------------------------------
# HAProxy stats page — mirrors the GitHub Actions "haproxy test" step.
# ---------------------------------------------------------------------------

@test "stats page is accessible on port 80" {
    _require_docker_socket
    run curl -sf "http://localhost:${TEST_PORT}/stats"
    [ "$status" -eq 0 ]
}

@test "stats page contains HAProxy version information" {
    _require_docker_socket
    run curl -s "http://localhost:${TEST_PORT}/stats"
    [ "$status" -eq 0 ]
    [[ "$output" =~ "HAProxy version" ]]
}

@test "stats page contains the statistics table" {
    _require_docker_socket
    run curl -s "http://localhost:${TEST_PORT}/stats"
    [ "$status" -eq 0 ]
    [[ "$output" =~ "class=px" ]]
}

# ---------------------------------------------------------------------------
# Integration — backend containers appear in the generated haproxy config.
# These tests mirror the "mailhog test" / backend discovery steps in CI.
# ---------------------------------------------------------------------------

@test "backend with AMAZEEIO env is added to haproxy config" {
    _require_docker_socket

    local backend_host="test-amazeeio.docker.amazee.io"

    docker rm -f "${BACKEND_AMAZEEIO}" 2>/dev/null || true
    docker run -d \
        --name "${BACKEND_AMAZEEIO}" \
        -e AMAZEEIO=AMAZEEIO \
        -e "AMAZEEIO_URL=${backend_host}" \
        -e AMAZEEIO_HTTP_PORT=80 \
        -p 80 \
        nginx:alpine

    # Wait for docker-gen to detect the new container and reload haproxy.
    local max_wait=20
    local waited=0
    until curl -s "http://localhost:${TEST_PORT}/stats" | grep -q "${backend_host}"; do
        sleep 1
        waited=$((waited + 1))
        [ "$waited" -lt "$max_wait" ] || break
    done

    run curl -s "http://localhost:${TEST_PORT}/stats"
    [ "$status" -eq 0 ]
    [[ "$output" =~ "${backend_host}" ]]

    docker rm -f "${BACKEND_AMAZEEIO}" 2>/dev/null || true
}

@test "backend with LAGOON_LOCALDEV_HTTP_PORT env is added to haproxy config" {
    _require_docker_socket

    local backend_host="lagoon-test.docker.amazee.io"

    docker rm -f "${BACKEND_LAGOON}" 2>/dev/null || true
    docker run -d \
        --name "${BACKEND_LAGOON}" \
        -e LAGOON_LOCALDEV_HTTP_PORT=8080 \
        -e "LAGOON_ROUTE=http://${backend_host}" \
        -p 8080 \
        nginx:alpine

    # Wait for docker-gen to detect the new container and reload haproxy.
    local max_wait=20
    local waited=0
    until curl -s "http://localhost:${TEST_PORT}/stats" | grep -q "${backend_host}"; do
        sleep 1
        waited=$((waited + 1))
        [ "$waited" -lt "$max_wait" ] || break
    done

    run curl -s "http://localhost:${TEST_PORT}/stats"
    [ "$status" -eq 0 ]
    [[ "$output" =~ "${backend_host}" ]]

    docker rm -f "${BACKEND_LAGOON}" 2>/dev/null || true
}
