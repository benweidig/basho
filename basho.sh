#!/usr/bin/env bash

################################################################################
# Bashō (芭蕉) - an exporter for Calibre
################################################################################
#
# Usage: ./basho.sh <library location> <metadata column>
#
# Arguments:
#   <library location>  Full path to your Calibre library
#
#   <metadata column>   Name of custom metadata column
#
# Requirements:
#   calibredv, jq, xmllint, bash4+
################################################################################

VERSION="0.0.1"

if [[ -n "$DEBUG" ]]; then
    set -x
fi

# VALIDATE ALL REQUIRED PROGRAMS ARE AVAILABLE

REQUIREMENTS=(calibredb xmllint jq)
for PROGRAM in "${REQUIREMENTS[@]}"; do
    command -v "$PROGRAM" > /dev/null 2>&1
    # shellcheck disable=SC2181
    if [[ $? -ne 0 ]]; then
        >&2 echo "Required '$PROGRAM' is not available"
        exit 1
    fi
done

# PRINT HELP IF NO ARGS
if [[ $# -lt 2 ]]; then
    echo "Bashō (芭蕉) - Calibre Exporter (${VERSION})"
    echo ""
    echo "Usage:  ${0##*/} <library location> <metadata column>"
    exit 1
fi

set -e

LIBRARY="${1}"
CUSTOM_METADATA_COL="${2}"

# 1. LOAD ALL BOOK IDS

BOOK_IDS=$(calibredb --with-library="$LIBRARY" list --for-machine | jq --compact-output --raw-output '.[].id')

if [[ -z "$BOOK_IDS" ]]; then
    >&2 echo "No books returned from calibredb"
    exit 1
fi

# 2. CHECK EFVERY BOOK FOR RELEVANT METADAT

while IFS= read -d $'\n' -r BOOK_ID ; do

    # 2a. GET OPF METADATA
    BOOK_OPF=$(calibredb --with-library="$LIBRARY" show_metadata --as-opf "$BOOK_ID")

    # 2b. EXTRACT RELEVANT METADATA
    OPF_CUSTOM_METADATA=$(xmllint --xpath "string(//*[local-name()='package']/*[local-name()='metadata']/*[local-name()='meta'][@name='calibre:user_metadata:#${CUSTOM_METADATA_COL}']/@content)" - <<< "$BOOK_OPF")

    if [[ -z "$OPF_CUSTOM_METADATA" ]]; then
        continue
    fi

    # 3. EXPORT BOOK FOR EVERY VALUE IN CUSTOM METADATA

    CUSTOM_METADATA_VALUES=$(jq --compact-output --raw-output '."#value#" | .[]' <<< "$OPF_CUSTOM_METADATA")

    if [[ -z "$CUSTOM_METADATA_VALUES" ]]; then
        continue
    fi

    while IFS= read -d $'\n' -r CUSTOM_METADATA_VALUE ; do

        if [[ -z "$CUSTOM_METADATA_VALUE" ]]; then
            continue
        fi

        echo "Exporting [$BOOK_ID] -> $CUSTOM_METADATA_VALUE"

        calibredb \
            --with-library="$LIBRARY" \
            export \
            --dont-save-cover \
            --dont-update-metadata \
            --dont-write-opf \
            --single-dir \
            --dont-asciiize \
            --template "{title} - {author_sort} [$BOOK_ID]" \
            --to-dir "$CUSTOM_METADATA_VALUE" \
            "$BOOK_ID"

    done < <(printf '%s\n' "$CUSTOM_METADATA_VALUES")

done < <(printf '%s\n' "$BOOK_IDS")
