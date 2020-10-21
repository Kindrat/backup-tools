#!/bin/bash

###################################################################
#Script Name	: backup.sh
#Description	: Creates a copy of job configurations for Jenkins instance for migration to another instance
#Args         : Hardcoded currently
#Author       : @Kindrat
#Email        : legioner.alexei@gmail.com
###################################################################
set -e

# Prints a string with current date to stdout - e.g. log message
function log() {
	echo -e "$(date)\t$@"
}

# Jenkins instance to load Job info from
JENKINS=https://jenkins.example.com
# Jenkins user to use for authorisation
LOGIN=admin_user
# Jenkins password to use for authorisation
PASSWORD=test_password

log "Fetching all Jenkins jobs"
JOBS=$(java -jar jenkins-cli.jar -s ${JENKINS} -auth ${LOGIN}:${PASSWORD} -webSocket list-jobs)
for job in ${JOBS}; do
  # We do not have file with config locally. Lets dump it from Jenkins
	if [[ ! -f ${job}.xml ]]; then
		log "Making backup for ${job}"
	  java -jar jenkins-cli.jar -s ${JENKINS} -auth ${LOGIN}:${PASSWORD} -webSocket get-job "${job}" > "${job}.xml"
	fi
done
log "Dumping credentials"
# Expecting to have all credentials in default namespace
java -jar jenkins-cli.jar -s ${JENKINS} -auth ${LOGIN}:${PASSWORD} -webSocket list-credentials-as-xml "system::system::jenkins" > _credentials.xml
log "Dumping plugins"
java -jar jenkins-cli.jar -s ${JENKINS} -auth ${LOGIN}:${PASSWORD} -webSocket list-plugins > _plugins
