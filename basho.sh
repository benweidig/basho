#!/usr/bin/env bash

################################################################################
# Bashō (芭蕉) - an exporter for Calibre
################################################################################
#
# Usage: ./basho.sh <arguments>
#
# Arguments:
#   -l <library>    Required: Full path to your Calibre library
#   -c <column>     Required: Name of custom metadata column
#   -f <formats>    Optional: formats CSV (e.g. epub,pdf) [default=all]
#   -o <output>     Optional: output location [default=$PWD]
#
# Requirements:
#   calibredb, jq, xmllint, bash4+
################################################################################

# 0. SCRIPT META STUFF

VERSION="0.0.2"

if [[ -n "$DEBUG" ]]; then
    set -x
fi

# 1. VALIDATE ALL REQUIRED PROGRAMS ARE AVAILABLE

REQUIREMENTS=(calibredb xmllint jq)
for PROGRAM in "${REQUIREMENTS[@]}"; do
    command -v "$PROGRAM" > /dev/null 2>&1
    # shellcheck disable=SC2181
    if [[ $? -ne 0 ]]; then
        >&2 echo "Required '$PROGRAM' is not available"
        exit 1
    fi
done

set -e

# 2. ARGUMENTS PARSING

FORMATS="all"
OUTPUT="$PWD"

while getopts "l:c:f:o:" arg; do
    case $arg in
        l)
            LIBRARY="$OPTARG"
            ;;
        c)
            CUSTOM_METADATA_COL="$OPTARG"
            ;;
        f)
            FORMATS="$OPTARG"
            ;;
        o)
            OUTPUT="$OPTARG"
            ;;
        *)
            echo "Bashō (芭蕉) - Calibre Exporter (${VERSION})"
            echo ""
            echo "Usage:  ${0##*/} -l/--library <library location> -c/--column <metadata column> [-f/--formats <formats-csv>]" 
            exit 1
            ;;
    esac
done

# 3. LOAD ALL BOOK IDS

BOOK_IDS=$(calibredb --with-library="$LIBRARY" list --for-machine | jq --compact-output --raw-output '.[].id')

if [[ -z "$BOOK_IDS" ]]; then
    >&2 echo "No books returned from calibredb"
    exit 1
fi

# 4. CHECK EFVERY BOOK FOR RELEVANT METADATA

while IFS= read -d $'\n' -r BOOK_ID ; do

    # 5. GET OPF METADATA
    BOOK_OPF=$(calibredb --with-library="$LIBRARY" show_metadata --as-opf "$BOOK_ID")

    # 6. EXTRACT RELEVANT METADATA
    OPF_CUSTOM_METADATA=$(xmllint --xpath "string(//*[local-name()='package']/*[local-name()='metadata']/*[local-name()='meta'][@name='calibre:user_metadata:#${CUSTOM_METADATA_COL}']/@content)" - <<< "$BOOK_OPF")

    if [[ -z "$OPF_CUSTOM_METADATA" ]]; then
        continue
    fi

    # 7. GET CUSTOM COLUMN VALUES

    CUSTOM_METADATA_VALUES=$(jq --compact-output --raw-output '."#value#" | .[]' <<< "$OPF_CUSTOM_METADATA")

    if [[ -z "$CUSTOM_METADATA_VALUES" ]]; then
        continue
    fi

    # 8. EXPORT BOOK FOR EVERY COLUMN
    while IFS= read -d $'\n' -r CUSTOM_METADATA_VALUE ; do

        if [[ -z "$CUSTOM_METADATA_VALUE" ]]; then
            continue
        fi

        printf 'Exporting [%s] -> %s\n' "$BOOK_ID" "$CUSTOM_METADATA_VALUE"

        calibredb \
            --with-library="$LIBRARY" \
            export \
            --dont-save-cover \
            --dont-update-metadata \
            --dont-write-opf \
            --formats "$FORMATS" \
            --single-dir \
            --dont-asciiize \
            --template "{title} - {author_sort} [$BOOK_ID]" \
            --to-dir "$OUTPUT/$CUSTOM_METADATA_VALUE" \
            "$BOOK_ID"

    done < <(printf '%s\n' "$CUSTOM_METADATA_VALUES")

done < <(printf '%s\n' "$BOOK_IDS")
