#!/bin/bash

# Setup the environment
BASEDIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

# Setup the environment
source ${BASEDIR}/scripts/setup-env

echo "Updating Git Tags..."
${GIT} fetch --tags

if test ${IS_WSL2}; then
  echo "Host OS: Linux (Windows with WSL2 backend)"
else
  echo "Host OS: ${OS}"
fi

echo "Host Arch: ${ARCH}"
echo "Devkit Base Path: ${BASEDIR}"

[ ! -d images ] && mkdir images

args=("$@")
case "${args[0]}" in
  setup|config|saveconfig|clean|build|rebuild|download|dependencies|buildtimegraph|buildsize|env|makesdk )
    source ${BASEDIR}/scripts/helper "${args[@]}"
  ;;

  docker )
    source ${BASEDIR}/scripts/docker "${args[@]:1}"
  ;;

  qemu )
    source ${BASEDIR}/scripts/qemu "${args[@]:1}"
  ;;

  initialize )
    git submodule update --init --recursive --remote --checkout
    git submodule update --recursive
    cd buildroot
    for patch in ../patches/*; do
      echo "Applying patch ${patch} to buildroot..."
      patch -s -p1 < ${patch}
    done
    cd ..
  ;;

  * )
    cat <<"EOF"

Vela: Operating System Builder

Commands:
  setup [<boardname>]     Sets up the buildroot environment with the specified {boardname}_defconfig, default: vela-qemu-x64
  config [<package>]
    - config [buildroot]  Opens the buildroot configuration
    - config linux        Opens the linux configuration
    - config busybox      Opens the busybox configuration
    - config barebox      Opens the barebox configuration
  saveconfig              Saves all configuration files from current working space into the prototype directory
  build [<package>]       Starts a build of VelaOS, default: build all
  rebuild <package>       Rebuilds a specific buildroot package
  clean
    - clean [all]         Cleans up the working space
    - clean target        Cleans the device' target directory only
    - clean ccache        Cleans the CCACHE cache directory
    - clean <package>     Cleans the build directory of the given package
  makesdk                 Prebuilds the SDK for reuse
  download                Downloads all necessary source packages without building them
  dependencies            Builds a dependency graph of packages
  buildtimegraph          Builds a graph of the compile times of all packages
  buildsize               Builds information about the package sizes in the target filesystem
  licenses                Builds the legal information of all packages in the target filesystem
  env                     Prints all build environment variables
  initialize              Initializes and downloads submodules
  restoresdk              Downloads and restores the prebuilt SDK
  docker
    - docker setup        Builds the initial VelaOS Buildsystem Docker image
    - docker clean        Rebuilds all volumes to clean up any state
    - docker rm           Removes all containers of the current setup
    - docker purge        Deletes everything related to the Docker image
    - docker shell        Starts the Docker container and jumps into the shell
    - docker store        Creates a new Docker tag for the image with the current status
    - docker reclaim      Cleans up any leftover, but unused Docker images, containers, ...
    - docker rebuild      Rebuilds the Docker image, used to run Buildroot. Containers are not rebuild
EOF
  ;;
esac