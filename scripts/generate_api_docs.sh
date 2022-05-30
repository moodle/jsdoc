#!/usr/bin/env bash
set -e

SCRIPTSDIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
ROOT="$( cd "$( dirname "${SCRIPTSDIR}" )" && pwd )"
PHPDOCROOT="${ROOT}/phpdocs"

VERSIONLIST=(${VERSIONLIST[@]:-master})
BRANCHLIST=(${BRANCHLIST[@]:-master})

echo "============================================================================"
echo "= Building for the following versions and branches:"
echo "= Versions: ${VERSIONLIST[*]}"
echo "= Branches: ${BRANCHLIST[*]}"
echo "============================================================================"

for index in ${!VERSIONLIST[@]}; do
  version=${VERSIONLIST[$index]}
  moodlebranch=${BRANCHLIST[$index]}
  APIDOCDIR="build/${version}"
  echo "========================================"
  echo "== Generating all API Documentation for ${version} using branch ${moodlebranch}"
  echo "== Generated documentation will be placed into ${APIDOCDIR}"
  echo "========================================"
  mkdir -p "${APIDOCDIR}"

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
  echo "== Moving jsdocs into ${APIDOCDIR}/jsdoc"
  echo "========================================"
  cd "${ROOT}"
  mv "${INPUT}/jsdoc" "${APIDOCDIR}/jsdoc"

  echo "========================================"
  echo "== Building PHP Documentation"
  echo "========================================"
  # Generate the php documentation
  docker run \
      -v "${ROOT}":"${ROOT}" \
      -w "${ROOT}" \
      -e HASH="${HASH}" \
      -e INPUT="${INPUT}" \
      -e VERSION="${version}" \
      -u "${UID}":"${UID}" \
      doxygen

  # Move the built files into the build directory
  echo "========================================"
  echo "== Moving phpdocs into ${APIDOCDIR}/phpdocs"
  echo "========================================"
  cd "${ROOT}"
  mv "build/phpdocs/${version}/html" "${APIDOCDIR}/phpdocs"

  echo "========================================"
  echo "== Completed documentation generation for ${version}"
  echo "========================================"
done

echo "============================================================================"
echo "= Documentation build completed."
echo "============================================================================"
