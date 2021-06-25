#!/usr/bin/env bash
set -o errexit

############################################################
# Help                                                     #
############################################################
Help() {
	# Display Help
	echo "Generate a container image for running Git and pre-commit hooks."
	echo
	echo "Syntax: pre-commit-image.sh [-a|h]"
	echo "options:"
	echo "a     Build for the specified target architecture, i.e. amd64, armhfp, arm64."
	echo "h     Print this Help."
	echo
}

############################################################
############################################################
# Main program                                             #
############################################################
############################################################

# Set variables
ARCHITECTURE="$(podman info --format=\{\{".Host.Arch"\}\})"

############################################################
# Process the input options. Add options as needed.        #
############################################################
while getopts ":a:h" option; do
	case $option in
	h) # display Help
		Help
		exit
		;;
	a) # Enter a target architecture
		ARCHITECTURE=$OPTARG ;;
	\?) # Invalid option
		echo "Error: Invalid option"
		exit
		;;
	esac
done

CONTAINER=$(buildah from --arch "$ARCHITECTURE" quay.io/containers/podman:latest)
IMAGE="pre-commit"

buildah run "$CONTAINER" /bin/sh -c 'dnf install -y git gnupg2 openssh pre-commit python3 python-unversioned-command --nodocs --setopt install_weak_deps=False'

buildah run "$CONTAINER" /bin/sh -c 'dnf clean all -y'

buildah run --user podman "$CONTAINER" /bin/sh -c 'mkdir /home/podman/mnt'

buildah config --user podman "$CONTAINER"

buildah config --workingdir /home/podman/mnt "$CONTAINER"

buildah config --label "io.containers.autoupdate=registry" "$CONTAINER"

buildah config --author "jordan@jwillikers.com" "$CONTAINER"

buildah commit "$CONTAINER" "$IMAGE"

buildah rm "$CONTAINER"
