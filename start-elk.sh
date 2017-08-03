#!/bin/bash

# Note! This file must not contain any carriage return characters, only line feed characters.

# Exit immediately if a command exits with a non-zero status.
set -e

gosu elk elasticsearch -d -Des.path.conf=/opt/config/elasticsearch/
gosu elk logstash -f /opt/config/logstash/ -l /opt/logs/logstash/logstash.log &
exec gosu elk kibana
