FROM haproxy:2.6-alpine3.17

USER root

RUN apk add --no-cache bash \
    && rm -rf /var/cache/apk/*

COPY --from=jwilder/docker-gen:latest /usr/local/bin/docker-gen /usr/local/bin/docker-gen

COPY . /app/
WORKDIR /app/

ENV DOCKER_HOST unix:///tmp/docker.sock
ENTRYPOINT ["/app/docker-entrypoint.sh"]
CMD ["/app/haproxy_start.sh"]
EXPOSE 80 443
