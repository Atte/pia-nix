#!/usr/bin/env bash
set -euo pipefail

if [ "$EUID" -ne 0 ]; then
    echo "This script must be run as root!" >&2
    exit 1
fi

name=''
ip=''
token=''
source /tmp/pia.info.sh

response="$(
    curl --silent --get \
        --connect-to "$name::$ip:" \
        --cacert "$PIA_CERT" \
        --data-urlencode "token=$token" \
        "https://$name:19999/getSignature"
)"
if [ "$(jq --raw-output '.status' <<<"$response")" != 'OK' ]; then
    echo 'getSignature error!' >&2
    echo "$response" >&2
    exit 1
fi
payload="$(jq --raw-output '.payload' <<<"$response")"
signature="$(jq --raw-output '.signature' <<<"$response")"
myport="$(base64 --decode <<<"$payload" | jq --raw-output '.port')"

echo "Forwarding port $myport" >&2
echo "PIA_PORT=$myport" >/tmp/pia.port.sh
cat >/tmp/pia.port.rtorrent <<EOF
branch = ((not, ((equal, ((network.listen.port)), ((value, $myport)))))), \\
    ((catch, \\
        ((network.port_range.set, $myport-$myport)), \\
        ((dht.port.set, $myport)), \\
    ))
EOF

if test -n "${TRANSMISSION_URL:-}"; then
    function transmission {
        local data="$1"

        auth=()
        if test -n "${TRANSMISSION_USERNAME:-}"; then
            auth=("--basic" "$TRANSMISSION_USERNAME:$TRANSMISSION_PASSWORD")
        fi

        sid="$(
            jq --null-input '.method = "session-stats"' | \
                curl --silent --include  \
                    -X HEAD \
                    "${auth[@]}" \
                    --data-binary '@-' \
                    --header 'Content-Type: application/json' \
                    --header 'Accept: application/json' \
                    "$TRANSMISSION_URL" | \
                sed --silent --regexp-extended 's/^X-Transmission-Session-Id: (\S+)/\1/p' | \
                tr -d '\r\n'
        )"

        curl --silent \
            "${auth[@]}" \
            --data-binary "$data" \
            --header 'Content-Type: application/json' \
            --header 'Accept: application/json' \
            --header "X-Transmission-Session-Id: $sid" \
            "$TRANSMISSION_URL"
    }

    # shellcheck disable=SC2016
    transmission "$(jq --null-input --argjson port "$myport" '.method = "session-set" | .arguments["peer-port"] = $port')"
fi

while true; do
    response="$(
        curl --silent --get \
            --connect-to "$name::$ip:" \
            --cacert "$PIA_CERT" \
            --data-urlencode "payload=$payload" \
            --data-urlencode "signature=$signature" \
            "https://$name:19999/bindPort"
    )"
    if [ "$(jq --raw-output '.status' <<<"$response")" != 'OK' ]; then
        echo 'bindPort error!' >&2
        echo "$response" >&2
        exit 1
    fi

    sleep 10m
done
