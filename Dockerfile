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
RUN chmod 755 /app/ruuvigw_mqtt_decode.pl

# Config and tags files are expected to be mounted as volumes at runtime.
# Default paths used by the script are config.txt and known_tags.txt in the
# working directory.

ENTRYPOINT ["perl", "/app/ruuvigw_mqtt_decode.pl"]
CMD ["-config=/config/config.txt", "-tags=/config/known_tags.txt"]
