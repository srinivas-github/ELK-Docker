# Docker image for ELK Stack
#### Prerequisites

 * We need to build a base image with Java8 and on Ubuntu
 * Goto Base-Image folder, and Issue the following command:
 * * ```
     $docker build -t base-image . 
     ```
 * After successful creation of base-image, go back to parent directory
 * Now to create docker image to be installed and configured with ELK
 * Issue the following command:
 ```
 $ docker build -t elk-demo .
 ```
 * To run the container, issue the following commands:
 ```
  $ docker run -d -p 5601:5601 -p 9200:9200 -p 5000:5000 -v /opt/config:/opt/config -v /opt/log:/opt/log elk-demo
  ```
  
 ###Description of Dockerfile (step - by - step):
 * FROM base-image
    * This specifies the Docker image on which this new Docker image is to be based upon.
 * Next follow a number of ENV declarations.
 * WORKDIR /opt
 	* Makes /opt the current working directory, similar to the cd shell command.
 * RUN groupadd -r elk && useradd -r -g elk elk
 	* The Docker RUN instruction executes commands. The groupadd shell command creates a system group with the name .elk. and the useradd command creates a system user .elk. belonging to the system group that was just created. Note that the .elk. user will not have a home directory, since it is a system user. This is the user that will run the programs of the ELK stack in the Docker image.

* The next RUN instruction installs gosu, which allows us to start processes that belong to a specific user.
* COPY ./start-elk.sh /opt/
	* Copies the script that is to launch the programs of the ELK stack when a Docker container is started from the directory in which the Docker-file is located to the /opt/ directory in the Docker image. 
* The next Docker instruction is RUN, which is followed by a large number of shell commands.
* The three wget commands will download Elasticsearch, Logstash and Kibana respectively.
* In the next step the downloaded archives are unpacked using the tar command.
* The x flag tells the tar command to extract files from an archive, the z flag cause unpacking of a gzip-archive and the f flag is used to specify the location of the archive from which to extract files. In addition, the C flag is used, which selects the directory to which the extracted files are to be written. The .strip-components=1 option will cause the first directory component of the files in the archive to be removed. If, for example, the path of a file in the archive is /dir1/dir2/dir3/file.txt the file will be written to dir2/dir3/file.txt in the destination directory when .strip-components=1.

* Having finished unpacking the Elasticsearch, Logstash and Kibana archives, they are deleted using the rm command.

* Next up is creation of the directories that are to hold log files for the three applications. I have chosen to locate these in a dedicated logs directory in order to be able to mount a host directory as a directory for log files.

* The two cp commands copy configuration files from the application home directories to the external configuration directories just created.
This creates a default configuration setup in the Docker image. If the user of the Docker image choose to map the entire external configuration directory (/opt/config) to a host directory or individual external configuration directories (for example /opt/config/kibana) the configuration of the entire ELK-stack or of individual applications may be customized.
The reason for not copying Logstash configuration files is that Logstash does not contain any configuration files.

* The six chown commands sets the owner of the three log and configuration directories and any files and directories inside these to the elk user created earlier in the Docker-file and the group to the elk group.
* Elasticsearch, Logstash and Kibana will be run by the elk user and in order for the three programs to be able to write log, the elk user needs to have write permissions to the log directories or be the owner of these directories.

* Elasticsearch will create a data directory in its home directory and thus this directory needs to be writeable by the user running Elasticsearch.

* ${ELASTICSEARCH_HOME}/bin/plugin -install lmenezes/elasticsearch-kopf
	* This line installs the Kopf Elasticsearch plug-in, which is an administration tool for Elasticsearch with a web GUI.

* ${LOGSTASH_HOME}/bin/plugin install logstash-input-jmx
	* Yet another plug-in installation, this time it is the Logstash JMX plug-in which is used to retrieve information from JMX beans exposed in a running JVM periodically.


* chmod +x /opt/start-elk.sh
	* Ensure that the start-elk.sh script is executable.

* sed -i -e.s|\${DIR}/config/kibana.yml|${KIBANA_CONFIG_FILE}|g. ${KIBANA_START_SCRIPT}
	* Modifies the Kibana start-script as to use the configuration file in the external (/opt/config/kibana) configuration directory.

* sed -i -e.s|# log_file: ./kibana.log|log_file: ${KIBANA_LOG_DIRECTORY}kibana.log|g. ${KIBANA_CONFIG_FILE}
	* Modifies the Kibana configuration file as to make Kibana write log to a file named kibana.log in the /opt/logs/kibana directory instead of writing log to standard out.

* sed -i -e.s|#path.logs: /path/to/logs|path.logs: ${ELASTICSEARCH_LOG_DIRECTORY}|g. ${ELASTICSEARCH_CONFIG_FILE}
	* In a similar manner, the Elasticsearch configuration file is modified as to redirect log output to the /opt/logs/elasticsearch directory.

* EXPOSE 5601 9200 5000
	* Tells Docker that a container created from this image will expose some kind of service on the ports 5601, 9200 and 5000.
In the case of this Docker image, the Kibana web GUI will be available on port 5601, the Elasticsearch REST API/Kopf administration tool on port 9200 and Logstash on port 5000.
Note that the EXPOSE instruction does not automatically expose the listed ports to the host when a container is created. To accomplish that the -p or -P flag must be used when launching the container.


* ENV PATH ${ELASTICSEARCH_HOME}/bin:$PATH
	* The above line is the first of three similar lines that adds the bin directories of Elasticsearch, Logstash and Kibana to the path. This enables us to execute the Elasticsearch, Logstash and Kibana binaries in a Docker container created from this image without having to specify an absolute path or changing directory.

* CMD [./opt/start-elk.sh.]
	* Specifies that, as default, the start-elk.sh script is to be launched whenever a container is created from this Docker image.
If another executable is provided when launching a container, this script will not be executed.
