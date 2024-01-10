#!/bin/bash
set -e

# this script requires the IROH_DOT_NETWORK_API_KEY env var to be set to your iroh.network api key

# create a fake data artifact, normally this would be the result of some prior computation
CURRENT_TIME=$(date +"%Y-%m-%dT%H:%M:%S")
echo "{ \"time\": \"$CURRENT_TIME\" }" > data.json

# this should be your iroh.network username/projectname that you want to upload to
PROJECT="b5/github_actions"
# create a document in your project & paste the doc id here
DOC_ID="5coyw3ythr3ctrh33vl6x63qv2qzg55iok7t5k6rkd2tdwbiq2wq"

# this script skips using iroh entirely, because all we need is iroh-bytes, iroh-net, and
# the iroh.network HTTP API. Sendme is iroh-bytes + iroh-net, so we'll use that for transfer
# install sendme
curl -fsSL https://iroh.computer/sendme.sh | sh

# add files & get ticket, saving process id so we can clean it up later
nohup ./sendme send ./data.json > ticket 2>&1 &
echo $! > save_pid.txt

# need to sleep long enough for the ticket to be generated
# (bad! this won't be an issue when working with iroh as a library)
sleep 5

# extract hash & size from sendme output
HASH=$(grep "hash" ticket | awk '{print $7}')
echo "Hash: ${HASH}"

# get file size
SIZE=$(wc -c < "data.json")

# extract ticket from sendme output
TICKET=$(grep "sendme receive" ticket | awk '{print $3}')
echo "Ticket: ${TICKET}"

# intiate sendme transfer to iroh.network iroh node
echo "Uploading content to iroh.network..."
curl "https://api.iroh.network/blobs/$PROJECT" \
  -X POST \
  -H "Authorization: Bearer ${IROH_DOT_NETWORK_API_KEY}" \
  -H "Content-Type: application/json" \
  -d "{\"ticket\": \"${TICKET}\", \"tag\": \"latest\"}"

# tell iroh.network to update the document entry
echo "Updating document entry..."
curl "https://api.iroh.network/docs/$PROJECT/${DOC_ID}/set-hash" \
  -X POST \
  -H "Authorization: Bearer ${IROH_DOT_NETWORK_API_KEY}" \
  -H "Content-Type: application/json" \
  -d "{ \"key\": \"data\", \"hash\": \"${HASH}\", \"size\": ${SIZE} }"

# cleanup
kill -9 `cat save_pid.txt`
rm save_pid.txt
rm ticket

echo "done"