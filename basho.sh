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
#   calibredb, jq, bash4+
################################################################################

# 0. SCRIPT META STUFF

VERSION="0.0.3"

if [[ -n "$DEBUG" ]]; then
    set -x
fi

# 1. VALIDATE ALL REQUIRED PROGRAMS ARE AVAILABLE

REQUIREMENTS=(calibredb jq)
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


# 3. LOAD ALL RELEVANT BOOKS

BOOKS=$(calibredb --with-library="$LIBRARY" list --for-machine --fields="*${CUSTOM_METADATA_COL},title" | jq --compact-output --raw-output ".[] | select(.[\"*${CUSTOM_METADATA_COL}\"] | length > 0)")

if [[ -z "$BOOKS" ]]; then
    >&2 echo "No books found for column '${CUSTOM_METADATA_COL}' from calibredb"
    exit 1
fi

# 4. EXPORT BOOKS

while IFS= read -d $'\n' -r BOOK ; do

    # 4a. EXTRACT BOOK INFOS
    BOOK_ID=$(jq --compact-output --raw-output ".id" <<< "$BOOK")
    BOOK_TITLE=$(jq --compact-output --raw-output ".title" <<< "$BOOK")

    # 4b. EXPORT BOOKB FOR EACH COL VALUE
    while IFS= read -d $'\n' -r CUSTOM_METADATA_VALUE ; do
        printf 'Exporting %s [%s] -> %s\n' "'$BOOK_TITLE'" "$BOOK_ID" "$CUSTOM_METADATA_VALUE"

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

    done < <(jq --compact-output --raw-output ".[\"*${CUSTOM_METADATA_COL}\"] | .[]" <<< "$BOOK")

done <<< "$BOOKS"
