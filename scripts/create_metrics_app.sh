#!/bin/sh

read -p "Instance URL (e.g https://example.com): " INSTANCE_URL

echo "Creating oauth app..."

RESP=$(curl \
    -XPOST \
    $INSTANCE_URL/api/v1/apps \
    --silent \
    --data-urlencode 'client_name=fedibash' \
    --data-urlencode 'redirect_uris=urn:ietf:wg:oauth:2.0:oob' \
    --data-urlencode 'scopes=admin:metrics' \
    --header "Content-Type: application/x-www-form-urlencoded"
)

client_id=$(echo $RESP | jq -r .client_id)
client_secret=$(echo $RESP | jq -r .client_secret)

if [ -z "$client_id" ]; then
  echo "Could not create an app"
  echo "$RESP"
  exit 1
fi

echo "Please visit the following URL and input the code provided"
AUTH_URL="$INSTANCE_URL/oauth/authorize?client_id=$client_id&redirect_uri=urn:ietf:wg:oauth:2.0:oob&scope=admin:metrics&response_type=code"
if [ ! -z "$BROWSER" ]; then
  $BROWSER $AUTH_URL
fi;

echo $AUTH_URL

read -p "Code: " CODE

echo "Requesting code..."

RESP=$(curl \
    -XPOST \
    $INSTANCE_URL/oauth/token \
    --silent \
    --header "Content-Type: application/x-www-form-urlencoded" \
    --data-urlencode "client_id=$client_id" \
    --data-urlencode "client_secret=$client_secret" \
    --data-urlencode "code=$CODE" \
    --data-urlencode "grant_type=authorization_code" \
    --data-urlencode 'redirect_uri=urn:ietf:wg:oauth:2.0:oob' \
    --data-urlencode "scope=admin:metrics"
)
echo $RESP
ACCESS_TOKEN="$(echo $RESP | jq -r .access_token)"

echo "Token is $ACCESS_TOKEN"
DOMAIN=$(echo $INSTANCE_URL | sed -e 's/^https:\/\///')

echo "Use the following config in your prometheus.yml:
- job_name: akkoma
  scheme: https
  authorization:
    credentials: $ACCESS_TOKEN
  metrics_path: /api/v1/akkoma/metrics
  static_configs:
  - targets:
    - $DOMAIN
"
