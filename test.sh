#!/usr/bin/env bash
set -o errexit

# Share storage.
# -v ~/.local/share/containers/storage:~/.local/share/containers/storage/shared:ro

distro=$(grep '^NAME=' /etc/os-release | cut -d '=' -f 2)

# Remove surrounding quotation marks, which are put there on Ubuntu.
distro=$(sed -e 's/^"//' -e 's/"$//' <<<"$distro")
echo "Linux distribution: $distro"

security_option='label=disable'
user_option=""
if [ "$distro" = "Ubuntu" ]; then
	security_option='apparmor=unconfined'
	# Necessary for weirdness on GitHub CI.
	user_option="--user=$(id -ur):$(id -gr)"
fi
echo "Security option: $security_option"

# Create a temporary directory
test_dir=$(mktemp -d -t test-pre-commit-image.XXXXXXXXXX)

# Configure a Git repository to use as a test case
git -C "$test_dir" init
git -C "$test_dir" config user.email "tester@testing.test"
git -C "$test_dir" config user.name "Tester Testington"
git -C "$test_dir" config commit.gpgSign false

# Add and stage a test file and a pre-commit configuration file

echo '#!/usr/bin/env bash
set -o errexit

echo "Hello World!"

' >"$test_dir/test.sh"
git -C "$test_dir" add test.sh

echo '
repos:
  - repo: https://github.com/pre-commit/pre-commit-hooks
    rev: v4.0.1
    hooks:
      - id: check-byte-order-marker
      - id: check-executables-have-shebangs
      - id: check-json
      - id: check-merge-conflict
      - id: check-yaml
      - id: end-of-file-fixer
      - id: mixed-line-ending
      - id: trailing-whitespace
  - repo: local
    hooks:
      - id: shellcheck
        name: shellcheck
        language: system
        entry: podman run --rm -v /home/podman/mnt:/mnt:Z docker.io/koalaman/shellcheck:latest
        args: [--color=always]
        types: [shell]
  - repo: local
    hooks:
      - id: shfmt
        name: shfmt
        language: system
        entry: podman run --rm -v /home/podman/mnt:/mnt:Z -w /mnt docker.io/mvdan/shfmt:latest
        args: [-w]
        types: [shell]

' >"$test_dir/.pre-commit-config.yaml"
git -C "$test_dir" add .pre-commit-config.yaml

# Test pre-commit install
podman run \
	--rm \
	--userns keep-id \
	"$user_option" \
	--device /dev/fuse \
	--security-opt "$security_option" \
	-v "$test_dir":/home/podman/mnt:Z \
	-v pre-commit:/home/podman/.local/share/containers/storage \
	--name pre-commit \
	localhost/pre-commit \
	pre-commit install

# Test that running the pre-commit hooks works
podman run \
	--rm \
	--userns keep-id \
	"$user_option" \
	--device /dev/fuse \
	--security-opt "$security_option" \
	-v "$test_dir":/home/podman/mnt:Z \
	-v pre-commit:/home/podman/.local/share/containers/storage \
	--name pre-commit \
	localhost/pre-commit \
	git commit -m "Test commit"

# Cleanup
rm -rf "$test_dir"
