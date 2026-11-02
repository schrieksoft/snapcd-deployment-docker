#!/bin/sh
# Stages the SSH key into ~/.ssh with the permissions OpenSSH requires. A key bind-mounted
# from a Windows host arrives world-readable, and OpenSSH refuses to use it.
set -e

STAGED=/run/secrets/ssh
SSH_DIR="$HOME/.ssh"

mkdir -p "$SSH_DIR"
chmod 700 "$SSH_DIR"

if [ -f "$STAGED/id_rsa" ]; then
    cp "$STAGED/id_rsa" "$SSH_DIR/id_rsa"
    chmod 600 "$SSH_DIR/id_rsa"
fi

if [ -f "$STAGED/known_hosts" ]; then
    cp "$STAGED/known_hosts" "$SSH_DIR/known_hosts"
    chmod 644 "$SSH_DIR/known_hosts"
fi

exec ./SnapCd.Runner "$@"
