# Docker image containing Elasticsearch, Logstash and Kibana.
#
# Run image with, for example:
# docker run -d -p 5601:5601 -p 9200:9200 -p 5000:5000 -v [path-to-configurations-root-on-host]:/opt/config -v [path-to-logs-root-on-host]:/opt/logs elk-demo
#
# View logs in Elasticsearch: curl 'http://[docker-container-ip]:9200/_search?pretty'
# Access Kibana: http://[docker-container-ip]:5601
# Access Kopf Elasticsearch admin GUI: http://[docker-container-ip]:9200/_plugin/kopf/#!/cluster
 
FROM base-image
 
ENV ELASTICSEARCH_VERSION 2.4.4
ENV LOGSTASH_VERSION 2.4.1
ENV KIBANA_VERSION 5.2.2
 
ENV CONFIG_ROOT /opt/config
ENV LOG_ROOT /opt/logs
 
ENV ELASTICSEARCH_HOME /opt/elasticsearch
ENV ELASTICSEARCH_ORIG_CONFIG_DIRECTORY ${ELASTICSEARCH_HOME}/config
ENV ELASTICSEARCH_CONFIG_FILE ${ELASTICSEARCH_ORIG_CONFIG_DIRECTORY}/elasticsearch.yml
ENV ELASTICSEARCH_LOG_DIRECTORY ${LOG_ROOT}/elasticsearch
ENV ELASTICSEARCH_CONFIG_DIRECTORY ${CONFIG_ROOT}/elasticsearch
 
ENV LOGSTASH_HOME /opt/logstash
ENV LOGSTASH_LOG_DIRECTORY ${LOG_ROOT}/logstash/
ENV LOGSTASH_CONFIG_DIRECTORY ${CONFIG_ROOT}/logstash
 
ENV KIBANA_HOME /opt/kibana
ENV KIBANA_ORIG_CONFIG_DIRECTORY ${KIBANA_HOME}/config
ENV KIBANA_LOG_DIRECTORY ${LOG_ROOT}/kibana/
ENV KIBANA_CONFIG_DIRECTORY ${CONFIG_ROOT}/kibana
ENV KIBANA_CONFIG_FILE ${KIBANA_CONFIG_DIRECTORY}/kibana.yml
ENV KIBANA_START_SCRIPT ${KIBANA_HOME}/bin/kibana
 
 
WORKDIR /opt
 
# Create the elk user and elk system group.
RUN groupadd -r elk && useradd -r -g elk elk
 
# Install gosu as to allow us to run programs with a specific user.
RUN apt-get update && apt-get install -y curl libossp-uuid-dev wget ca-certificates git make && rm -rf /var/lib/apt/lists/* && \
    curl -o /usr/local/bin/gosu -SL 'https://github.com/tianon/gosu/releases/download/1.1/gosu' && \
    chmod +x /usr/local/bin/gosu && \
    apt-get purge -y --auto-remove curl
	
# Copy the script used to launch the ELK-stack when a container is started.
COPY ./start-elk.sh /opt/
 
# Download Elasticsearch, Logstash and Kibana.
RUN wget https://download.elastic.co/elasticsearch/release/org/elasticsearch/distribution/tar/elasticsearch/${ELASTICSEARCH_VERSION}/elasticsearch-${ELASTICSEARCH_VERSION}.tar.gz

RUN wget https://download.elastic.co/logstash/logstash/logstash-${LOGSTASH_VERSION}.tar.gz
RUN wget https://artifacts.elastic.co/downloads/kibana/kibana-${KIBANA_VERSION}-linux-x86_64.tar.gz


# Create home directories.
RUN mkdir ${ELASTICSEARCH_HOME} 
RUN mkdir ${LOGSTASH_HOME} 
RUN mkdir ${KIBANA_HOME}

# Extract Elasticsearch, Logstash and Kibana to respective directories.
RUN tar -xzf elasticsearch*.tar.gz  -C ${ELASTICSEARCH_HOME} --strip-components=1
RUN tar -xzf logstash*.tar.gz  -C ${LOGSTASH_HOME} --strip-components=1
RUN tar -xzf kibana*.tar.gz  -C ${KIBANA_HOME} --strip-components=1


# Remove archives.
RUN rm *.tar.gz

# Create log directories.
RUN mkdir -p ${LOGSTASH_LOG_DIRECTORY}
RUN mkdir -p ${ELASTICSEARCH_LOG_DIRECTORY}
RUN mkdir -p ${KIBANA_LOG_DIRECTORY}
# Create external configuration directories.
RUN mkdir -p ${ELASTICSEARCH_CONFIG_DIRECTORY}
RUN mkdir -p ${LOGSTASH_CONFIG_DIRECTORY}
RUN mkdir -p ${KIBANA_CONFIG_DIRECTORY}

# Copy configuration to external configuration directories.
RUN cp ${ELASTICSEARCH_ORIG_CONFIG_DIRECTORY}/*.* ${ELASTICSEARCH_CONFIG_DIRECTORY}
RUN cp ${KIBANA_ORIG_CONFIG_DIRECTORY}/*.* ${KIBANA_CONFIG_DIRECTORY} 

# Set owner of log directories to the user that runs the applications.
RUN chown -hR elk:elk ${LOGSTASH_LOG_DIRECTORY}
RUN chown -hR elk:elk ${ELASTICSEARCH_LOG_DIRECTORY}
RUN chown -hR elk:elk ${KIBANA_LOG_DIRECTORY}

# Set owner of configuration directories to the user that runs the applications.
RUN chown -hR elk:elk ${LOGSTASH_CONFIG_DIRECTORY}
RUN chown -hR elk:elk ${ELASTICSEARCH_CONFIG_DIRECTORY}
RUN chown -hR elk:elk ${KIBANA_CONFIG_DIRECTORY}

# Set owner of Elasticsearch directory so that data directory can be created.
RUN chown -hR elk:elk ${ELASTICSEARCH_HOME}
# Install Elasticsearch kopf plug-in: https://github.com/lmenezes/elasticsearch-kopf
RUN ${ELASTICSEARCH_HOME}/bin/plugin install lmenezes/elasticsearch-kopf
# Install Logstash JMX plug-in.
RUN ${LOGSTASH_HOME}/bin/plugin install logstash-input-jmx
# Make the start-script executable.
RUN  chmod +x /opt/start-elk.sh
# Modify Kibana start-script as to use external configuration file.
RUN  sed -i -e"s|\${DIR}/config/kibana.yml|${KIBANA_CONFIG_FILE}|g" ${KIBANA_START_SCRIPT}
# Modify Kibana configuration as to log to the dedicated logging directory instead of standard out.
RUN sed -i -e"s|# log_file: ./kibana.log|log_file: ${KIBANA_LOG_DIRECTORY}kibana.log|g" ${KIBANA_CONFIG_FILE}
# Modify Elasticsearch configuration to log to the dedicated logging directory.
RUN sed -i -e"s|#path.logs: /path/to/logs|path.logs: ${ELASTICSEARCH_LOG_DIRECTORY}|g" ${ELASTICSEARCH_CONFIG_FILE}
 
# Kibana UI port, Elasticsearch REST API/Kopf port and Logstash.
EXPOSE 5601 9200 5000
 
# Add Elasticsearch, Logstash and Kibana bin directories to path.
ENV PATH ${ELASTICSEARCH_HOME}/bin:$PATH
ENV PATH ${LOGSTASH_HOME}/bin:$PATH
ENV PATH ${KIBANA_HOME}/bin:$PATH
 
# Launch the ELK stack when a container is started.
CMD ["/opt/start-elk.sh"]
