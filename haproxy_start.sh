#!/bin/bash

# If TLS_CERT points to an existing file, copy it into place before docker-gen starts.
if [ -n "${TLS_CERT}" ]; then
    if [ -f "${TLS_CERT}" ]; then
        cp "${TLS_CERT}" /app/server.pem
        echo "TLS certificate loaded from ${TLS_CERT}"
    else
        echo "Warning: TLS_CERT is set but file '${TLS_CERT}' does not exist — HTTPS frontend will be disabled"
        rm -f /app/server.pem
    fi
fi

haproxy -f /app/haproxy.cfg
docker-gen -watch -only-exposed -notify "/app/haproxy_reload.sh" /app/haproxy.tmpl /app/haproxy.cfg