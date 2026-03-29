FROM perl:5.38-slim

# Install system dependencies needed by IPC::Shareable and build tools
RUN apt-get update && apt-get install -y --no-install-recommends \
        build-essential \
        libssl-dev \
    && rm -rf /var/lib/apt/lists/*

# Install CPAN modules
RUN cpanm --notest \
        Net::MQTT::Simple \
        JSON::PP \
        Async::Event::Interval \
        IPC::Shareable

WORKDIR /app

COPY ruuvigw_mqtt_decode.pl /app/ruuvigw_mqtt_decode.pl
COPY sample/ /app/sample/
COPY docker-entrypoint.sh /app/docker-entrypoint.sh
RUN chmod 755 /app/ruuvigw_mqtt_decode.pl /app/docker-entrypoint.sh

# Config and known_tags files are mounted via a volume at /config/ at runtime.
# The entrypoint script copies the sample files there if they are not present yet.

ENTRYPOINT ["/app/docker-entrypoint.sh"]
CMD ["-config=/config/config.txt", "-tags=/config/known_tags.txt"]
