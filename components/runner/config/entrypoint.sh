#!/bin/sh
# Stages the SSH key into ~/.ssh with the permissions OpenSSH requires. A key bind-mounted
# from a Windows host arrives world-readable, and OpenSSH refuses to use it.
set -e

STAGED=/run/secrets/ssh

mkdir -p /root/.ssh
chmod 700 /root/.ssh

if [ -f "$STAGED/id_rsa" ]; then
    cp "$STAGED/id_rsa" /root/.ssh/id_rsa
    chmod 600 /root/.ssh/id_rsa
fi

if [ -f "$STAGED/known_hosts" ]; then
    cp "$STAGED/known_hosts" /root/.ssh/known_hosts
    chmod 644 /root/.ssh/known_hosts
fi

exec ./SnapCd.Runner "$@"
