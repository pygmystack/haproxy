# the pygmy stack - haproxy image

This image is a multiarchitecture compatible docker image

This build a docker image from [haproxy](https://github.com/haproxy/haproxy/) with [nginx-proxy/docker-gen](https://github.com/nginx-proxy/docker-gen) pre-installed and configured to serve as a reverse proxy.

This images provides a haproxy that serves as an reverse proxy in front of multiple Containers. This allows us to access multiple containers via nice URLs without the need to publish or know the ports of the containers.

## Usage

When used together with pygmy everything is already setup and ready to go. You don't have to worry more.

## Start manually

       docker run -d -p 80:80 -p 443:443 --volume=/var/run/docker.sock:/tmp/docker.sock --name=amazeeio-haproxy pygmystack/haproxy

By default this Image will listen to port 80 and 443 for http and https connections. It is not forced though to this, with defining another port this Image also works, example:

       docker run -d -p 8080:80 -p 4443:443 --volume=/var/run/docker.sock:/tmp/docker.sock --name=amazeeio-haproxy pygmystack/haproxy

## How it works

The container has [docker-gen](https://github.com/jwilder/docker-gen) installed, which listens to the Docker socket for changes of containers.

Every container that has an environment variable `AMAZEEIO` set, docker-gen will generate from the template (haproxy.tmpl)[./haproxy.tmpl] and haproxy config and restart the haproxy.

## Use with non-amazeeio containers

This container can not only be used for Containers started from amazee.io Docker Images, it can reverse proxy any kind of Containers. In order to do so, start your container with the following environment variables:

- `AMAZEEIO` - Tells docker-gen that this container should be handled (value does not matter, just use `AMAZEEIO=AMAZEEIO`)
- `AMAZEEIO_URL` - the URL for which connections should be forwarded to by haproxy (if not set, falls back to the Container name. Plus make sure that your DNS resolves the given URL to the IP of the Docker Host)
- `AMAZEEIO_HTTP_PORT` - the port were the container listens for HTTP Connections, this port also needs to be exposed via the container (falls back to 80 if not set)
- `AMAZEEIO_HTTPS_PORT` - the port were the container listens for HTTPS Connections, this port also needs to be exposed via the container (falls back to 443 if not set)

Example:

        docker run --rm -e AMAZEEIO_URL=nginx.docker.amazee.io -e AMAZEEIO=AMAZEEIO -e AMAZEEIO_HTTP_PORT=80 -p 80 nginx

## Problem resolving

The haproxy exposes it's status page on `/stats` (like: http://docker.amazee.io/stats if used with amazee.io). There you can see the containers, their ports and their URLs for which reverse proxy entries are made.

If something doesn't work at all, run `haproxy -f haproxy.cfg -d` within the running container (it should be running even if there is an haproxy error), this will start haproxy in debug mode and should show you possible errors.

## Development

For easier development, there is an docker-compose.yml file which starts the an container and mounts the template file into the container for easier development.
