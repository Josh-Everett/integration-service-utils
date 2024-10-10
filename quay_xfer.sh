#!/bin/bash

### requires jq + skopeo to be installed locally

# arg check
if [ $# -ne 2 ]; then
  echo "Usage: $0 source_namespace/source_repo dest_namespace/dest_repo"
  exit 1
fi

SOURCE_REPO="$1"
DEST_REPO="$2"

# quay credentials
USERNAME=''
PASSWORD=''

# build skopeo command
SKOPEO_CMD="skopeo copy --all"

if [ -n "USERNAME" ] && [ -n "PASSWORD" ]; then
  SKOPEO_CMD+=" --src-creds ${USERNAME}:${PASSWORD} --dest-creds ${USERNAME}:${PASSWORD}"
else
  echo "Exiting - require credentials"
  exit 1
fi



# fetch tags from the source repo with pagination
TAGS=()
page=1
echo "Begin fetching tags"

while :; do
  echo "Fetching tags from page $page..."
  RESPONSE=$(curl -s "https://quay.io/api/v1/repository/${SOURCE_REPO}/tag/?page=${page}&limit=100")

  if [ -z "$RESPONSE" ]; then
    echo "Error fetching tags from quay.io"
    exit 1
  fi

  TAGS_PAGE=$(echo "$RESPONSE" | jq -r '.tags[].name')

  if [ -z "$TAGS_PAGE" ]; then
    echo "No tags found on page $page"
    break
  fi

  TAGS+=($TAGS_PAGE)
  HAS_ADDITIONAL=$(echo "$RESPONSE" | jq '.has_additional')

  if [ "$HAS_ADDITIONAL" = "true" ]; then
    page=$((page+1))
  else
    break
  fi
done

echo "Total tags to copy: ${#TAGS[@]}"

# copy each tag
for TAG in "${TAGS[@]}"; do
  echo "Copying tag $TAG..."
  $SKOPEO_CMD docker://quay.io/${SOURCE_REPO}:${TAG} docker://quay.io/${DEST_REPO}:${TAG}
done