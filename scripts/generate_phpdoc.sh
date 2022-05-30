#!/usr/bin/env bash

SCRIPTSDIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
ROOT="$( cd "$( dirname "${SCRIPTSDIR}" )" && pwd )"
VERSION="${VERSION:-master}"
PHPDOCROOT="${ROOT}/phpdocs"
DOXYGEN="${DOXYGEN:-`which doxygen`}"
cd "${PHPDOCROOT}"

export INPUT="${INPUT:-${ROOT}/.moodle}"

# Shared settings for all branches.
export INPUT_FILTER="${PHPDOCROOT}/doxygen-filter.php"
export PROJECT_NAME="Moodle PHP Documentation"
export INLINE_INHERITED_MEMB=YES # Show inherited members inline.
export TYPE="${TYPE:-html}"
export DOXYFILE="Doxyfile"
export HTML_EXTRA_STYLESHEET=doxygen-styles.css

export OUTPUT="${ROOT}/build/phpdocs/${VERSION}"
export OUTPUT_DIRECTORY="${OUTPUT}"
export BUILDLOGS="${ROOT}/logs"

TEMPDIR=`mktemp -d`
INCLUDEFILE="${TEMPDIR}/Doxyfile"

export EXCLUDE_PATTERNS=
if [[ -r "${INPUT}/.stylelintignore" ]]; then
    while IFS= read -r line
    do
        [[ "${line}" =~ ^#.* ]] && continue
        echo "EXCLUDE_PATTERNS += */${line}*" >> "${INCLUDEFILE}"
    done < "${INPUT}/.stylelintignore"
fi

# Add some EXCLUDE_PATTERNS defaults (last without backslash!
# (not sure about the tinymce & pear but they are noisy so keeping them out. Maybe some need to be added to thirdpaty.xml ?)
echo "EXCLUDE_PATTERNS += */.git/*" >> "${INCLUDEFILE}"
echo "EXCLUDE_PATTERNS += */lib/pear/*" >> "${INCLUDEFILE}"
echo "EXCLUDE_PATTERNS += */tests/*_test.php" >> "${INCLUDEFILE}"
echo "EXCLUDE_PATTERNS += */tests/fixtures/*" >> "${INCLUDEFILE}"
echo "EXCLUDE_PATTERNS += */node_modules/*" >> "${INCLUDEFILE}"
echo "EXCLUDE_PATTERNS += */vendor/*" >> "${INCLUDEFILE}"
echo "EXCLUDE_PATTERNS += */amd/*" >> "${INCLUDEFILE}"
echo "EXCLUDE_PATTERNS += */yui/*" >> "${INCLUDEFILE}"

# Calculate PROJECT_NUMBER, PROJECT_BRIEF and PROJECT BUILD from version.php (-- if not found)
export PROJECT_BRIEF="--"
export PROJECT_NUMBER="--"
export PROJECT_BUILD="--"
if [[ -r "${INPUT}/version.php" ]]; then
    release=$(grep '^$release' "${INPUT}/version.php")
    if [[ ${release} =~ [^\']+\'([^\']+)\'.* ]]; then
        PROJECT_BRIEF="Moodle ${BASH_REMATCH[1]}"
        if [[ ${PROJECT_BRIEF} =~ ([0-9]+\.[0-9]+).+ ]]; then
            PROJECT_NUMBER=${BASH_REMATCH[1]}
        fi
    fi
    if [[ ${release} =~ \(Build:\ ([0-9]+)\) ]]; then
        PROJECT_BUILD=${BASH_REMATCH[1]}
    fi
fi

if [[ ! -z "${HASH}" ]]; then
  export PROJECT_BUILD="${PROJECT_BUILD} (${HASH})"
  export PROJECT_BRIEF="${PROJECT_BRIEF} (${HASH})"
fi

if [[ ${PROJECT_NUMBER} == '--' ]]; then
    echo "This doesn't seem to be a moodle root directory. Aborting."
    exit 1
fi

# Clean any previous generated stuff
rm -fr ${OUTPUT_DIRECTORY}/html ${OUTPUT_DIRECTORY}/xml

# Run Doxygen from script dir
echo "Building PHP Documentation using:"
echo "    - Input ${INPUT}"
echo "    - Generating ${TYPE}"
echo "    - Output: ${OUTPUT}"
echo "    - Output: ${OUTPUT_DIRECTORY}"
echo "    - Project brief: ${PROJECT_BRIEF}"
echo "    - Using Doxyfile: ${DOXYFILE}"

mkdir -p "${OUTPUT}" "${BUILDLOGS}"
(cat "${PHPDOCROOT}/${DOXYFILE}"; echo @INCLUDE = "${INCLUDEFILE}") | doxygen - > "${BUILDLOGS}/Doxygen.out" 2>&1
