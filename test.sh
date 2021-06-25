#!/usr/bin/env bash
set -o errexit

# Share storage.
# -v ~/.local/share/containers/storage:~/.local/share/containers/storage/shared:ro

podman run --rm --userns keep-id --user podman:podman --device /dev/fuse --security-opt label=disable --volume pre-commit-image:~/.local/share/containers/storage --name test-container localhost/pre-commit podman run registry.fedoraproject.org/fedora-minimal:latest echo "Hello World!"
