#!/bin/bash

set -Eeuo pipefail

cat /dev/console &

/usr/local/bin/dind \
	dockerd \
	--host=unix:///var/run/docker.sock \
	--host=tcp://0.0.0.0:2375 \
	--storage-driver=vfs \
	&

exec /usr/sbin/sshd -D
