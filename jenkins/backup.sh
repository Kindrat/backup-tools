#!/bin/bash

set -e

function log() {
	echo -e "$(date)\t$@"
}

JENKINS=https://jenkins.example.com
LOGIN=admin
PASSWORD=test

log "Fetching all Jenkins jobs"
JOBS=$(java -jar jenkins-cli.jar -s ${JENKINS} -auth ${LOGIN}:${PASSWORD} -webSocket list-jobs)
for job in ${JOBS}; do
	if [[ ! -f ${job}.xml ]]; then
		log "Making backup for ${job}"
	  java -jar jenkins-cli.jar -s ${JENKINS} -auth ${LOGIN}:${PASSWORD} -webSocket get-job ${job} > ${job}.xml
	fi
done
log "Dumping credentials"
java -jar jenkins-cli.jar -s ${JENKINS} -auth ${LOGIN}:${PASSWORD} -webSocket list-credentials-as-xml "system::system::jenkins" > _credentials.xml
log "Dumping plugins"
java -jar jenkins-cli.jar -s ${JENKINS} -auth ${LOGIN}:${PASSWORD} -webSocket list-plugins > _plugins
