#!/usr/bin/env bats
# Image structure tests — verify binaries, files, and configuration baked into
# the image.  These tests run ephemeral containers and do not require access to
# the Docker socket.

IMAGE="${IMAGE_NAME:-pygmystack/haproxy:test}"

# ---------------------------------------------------------------------------
# Binaries
# ---------------------------------------------------------------------------

@test "haproxy binary is available in PATH" {
    run docker run --rm --entrypoint which "${IMAGE}" haproxy
    [ "$status" -eq 0 ]
    [ -n "$output" ]
}

@test "haproxy version matches Dockerfile" {
    local expected_version
    expected_version="$(grep -oE '^FROM haproxy:[0-9]+\.[0-9]+' "${BATS_TEST_DIRNAME}/../Dockerfile" | grep -oE '[0-9]+\.[0-9]+')"
    run docker run --rm "${IMAGE}" sh -c 'haproxy -v 2>&1'
    [ "$status" -eq 0 ]
    [[ "$output" =~ "HAProxy version ${expected_version}" ]]
}

@test "docker-gen binary is available in PATH" {
    run docker run --rm --entrypoint which "${IMAGE}" docker-gen
    [ "$status" -eq 0 ]
    [ -n "$output" ]
}

@test "bash is installed" {
    run docker run --rm "${IMAGE}" sh -c 'bash --version 2>&1'
    [ "$status" -eq 0 ]
    [[ "$output" =~ "GNU bash" ]]
}

# ---------------------------------------------------------------------------
# Required files
# ---------------------------------------------------------------------------

@test "/app/haproxy.cfg exists" {
    run docker run --rm "${IMAGE}" test -f /app/haproxy.cfg
    [ "$status" -eq 0 ]
}

@test "/app/haproxy.tmpl exists" {
    run docker run --rm "${IMAGE}" test -f /app/haproxy.tmpl
    [ "$status" -eq 0 ]
}

@test "/app/docker-entrypoint.sh is executable" {
    run docker run --rm "${IMAGE}" test -x /app/docker-entrypoint.sh
    [ "$status" -eq 0 ]
}

@test "/app/haproxy_start.sh is executable" {
    run docker run --rm "${IMAGE}" test -x /app/haproxy_start.sh
    [ "$status" -eq 0 ]
}

@test "/app/haproxy_reload.sh is executable" {
    run docker run --rm "${IMAGE}" test -x /app/haproxy_reload.sh
    [ "$status" -eq 0 ]
}

# ---------------------------------------------------------------------------
# Container environment
# ---------------------------------------------------------------------------

@test "working directory is /app" {
    run docker run --rm --entrypoint sh "${IMAGE}" -c 'pwd'
    [ "$status" -eq 0 ]
    [ "$output" = "/app" ]
}

@test "DOCKER_HOST is set to the expected unix socket path" {
    run docker inspect --format='{{range .Config.Env}}{{println .}}{{end}}' "${IMAGE}"
    [ "$status" -eq 0 ]
    [[ "$output" =~ "DOCKER_HOST=unix:///tmp/docker.sock" ]]
}

# ---------------------------------------------------------------------------
# HAProxy config validation
# ---------------------------------------------------------------------------

@test "haproxy config checker accepts a valid config" {
    # The baked-in haproxy.cfg is an intentionally minimal bootstrap config
    # (no backend) that docker-gen immediately replaces at runtime.  Instead,
    # verify that the haproxy binary itself correctly validates a well-formed
    # config, proving the binary is functional.
    run docker run --rm --entrypoint sh "${IMAGE}" -c '
cat > /tmp/valid.cfg <<HPXY
global
  daemon
  maxconn 1024
defaults
  mode http
  timeout client 60s
  timeout connect 60s
  timeout server 60s
frontend http
  bind :80
  default_backend be
backend be
  mode http
HPXY
haproxy -c -f /tmp/valid.cfg'
    [ "$status" -eq 0 ]
}

# ---------------------------------------------------------------------------
# Exposed ports (image metadata)
# ---------------------------------------------------------------------------

@test "image exposes port 80" {
    run docker inspect --format='{{json .Config.ExposedPorts}}' "${IMAGE}"
    [ "$status" -eq 0 ]
    [[ "$output" =~ "80/tcp" ]]
}

@test "image exposes port 443" {
    run docker inspect --format='{{json .Config.ExposedPorts}}' "${IMAGE}"
    [ "$status" -eq 0 ]
    [[ "$output" =~ "443/tcp" ]]
}
