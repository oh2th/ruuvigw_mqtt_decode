#!/bin/sh
set -e

# Copy sample config files to /config/ if they are not already there.
# This lets users edit them on the host before the script uses them.
if [ ! -f /config/config.txt ]; then
    echo "No config.txt found in /config/ — copying sample config."
    cp /app/sample/config.txt /config/config.txt
fi

if [ ! -f /config/known_tags.txt ]; then
    echo "No known_tags.txt found in /config/ — copying sample known_tags."
    cp /app/sample/known_tags.txt /config/known_tags.txt
fi

exec perl /app/ruuvigw_mqtt_decode.pl "$@"
