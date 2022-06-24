#!/usr/bin/env bash
set -e

SCRIPTSDIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
ROOT="$( cd "$( dirname "${SCRIPTSDIR}" )" && pwd )"
PHPDOCROOT="${ROOT}/phpdocs"

VERSIONLIST=(${VERSIONLIST[@]:-master})
BRANCHLIST=(${BRANCHLIST[@]:-master})

mkdir -p build
echo "============================================================================"
echo "= Building for the following versions and branches:"
echo "= Versions: ${VERSIONLIST[*]}"
echo "= Branches: ${BRANCHLIST[*]}"
echo "============================================================================"

htmlbranchlist=""

for index in ${!VERSIONLIST[@]}; do
  version=${VERSIONLIST[$index]}
  moodlebranch=${BRANCHLIST[$index]}
  APIDOCDIR="build/${version}"
  echo "========================================"
  echo "== Generating JavaScript API Documentation for ${version} using branch ${moodlebranch}"
  echo "== Generated documentation will be placed into ${APIDOCDIR}"
  echo "========================================"

  # Change into the Moodle directory to get some information.
  export INPUT="${ROOT}/.moodle"
  cd "${INPUT}"

  # Checkout the correct branch.
  echo "Checking out remote branch"
  git fetch origin "${moodlebranch}"
  git checkout "remotes/origin/${moodlebranch}"
  HASH=`git log -1 --format="%h"`

  echo "========================================"
  echo "== Installing NodeJS Dependencies"
  echo "========================================"
  npm ci

  echo "========================================"
  echo "== Generating ignorefiles"
  echo "========================================"
  npx grunt ignorefiles

  echo "========================================"
  echo "== Generating JS Documentation"
  echo "========================================"
  npx grunt jsdoc

  echo "========================================"
  echo "== Moving jsdocs into ${APIDOCDIR}"
  cd "${ROOT}"
  mv "${INPUT}/jsdoc" "${APIDOCDIR}"

  echo "== Completed documentation generation for ${version}"

  htmlbranchlist="${htmlbranchlist}
        <li><a href='./${version}'>Moodle ${version}</a></li>"
done

cat "${ROOT}/index.head.tpl" > "${ROOT}/build/index.html"
echo "${htmlbranchlist}" >> "${ROOT}/build/index.html"
cat "${ROOT}/index.foot.tpl" >> "${ROOT}/build/index.html"

echo "============================================================================"
echo "= Documentation build completed."
echo "============================================================================"
