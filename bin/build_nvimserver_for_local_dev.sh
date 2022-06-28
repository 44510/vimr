#!/bin/bash
set -Eeuo pipefail

declare -r -x clean=${clean:-false}
declare -r -x build_libnvim=${build_libnvim:-true}
declare -r -x build_dir=${build_dir:-"./.build"}

main() {
  pushd "$(dirname "${BASH_SOURCE[0]}")/.." >/dev/null

  pushd "./NvimServer"
    ./NvimServer/bin/build_nvimserver.sh
    cp ./.build/apple/Products/Release/NvimServer ../NvimView/Sources/NvimView/Resources
    cp -r ./runtime ../NvimView/Sources/NvimView/Resources
    cp ../NvimView/Sources/NvimView/Resources/com.qvacua.NvimView.vim ../NvimView/Sources/NvimView/Resources/runtime/plugin
  popd >/dev/null

  popd >/dev/null
}

main
