#!/bin/bash

set -e

function log() {
	echo -e "$(date)\t$@"
}

function containsElement() {
  local e match="$1"
  shift
  for e; do [[ "$e" == "$match" ]] && return 0; done
  return 1
}

JENKINS=https://new.jenkins.example.com
INITIAL_SOURCE=gitlab.com:project
SOURCE_REPLACEMENT=gitlab.example.com:project
LOGIN=admin
PASSWORD=test

log "Installing plugins"
INSTALLED_PLUGINS=$(java -jar jenkins-cli.jar -s ${JENKINS} -auth ${LOGIN}:${PASSWORD} list-plugins | awk '{print $1}' | sort)
PLUGINS=$(awk -e '{print $1}' _plugins | sort)
for plugin in ${PLUGINS}; do
	if $(containsElement ${plugin} ${INSTALLED_PLUGINS[@]}); then
		log "Skipping installed plugin ${plugin}"
	else
		log "Installing plugin ${plugin}"
		java -jar jenkins-cli.jar -s ${JENKINS} -auth ${LOGIN}:${PASSWORD} install-plugin ${plugin}
	fi
done
log "Restoring credentials"
java -jar jenkins-cli.jar -s ${JENKINS} -auth ${LOGIN}:${PASSWORD} import-credentials-as-xml "system::system::jenkins" < ./_credentials.xml
log "Restored credentials"
log "Restarting"
java -jar jenkins-cli.jar -s ${JENKINS} -auth ${LOGIN}:${PASSWORD} restart

while [ $(java -jar jenkins-cli.jar -s ${JENKINS} -auth ${LOGIN}:${PASSWORD} session-id &>/dev/null; echo $?) -ne 0 ]
do
   log "Waiting for Jenkins to start"
   sleep 2
done

log "Restoring jobs"
JOBS=$(find ./ -name "[a-z]*.xml" | sort)
EXISTING_JOBS=$(java -jar jenkins-cli.jar -s ${JENKINS} -auth ${LOGIN}:${PASSWORD} list-jobs)
for job in ${JOBS}; do
	job_name=$(echo ${job} | awk -F.xml '{print $1}' | awk -F/ '{print $2}')
	if $(containsElement ${job_name} ${EXISTING_JOBS[@]}); then
		log "Skipping existing job: ${job_name}"
	else
		log "Creating job: ${job_name}"
		cat "${job}" | sed "s|${INITIAL_SOURCE}|${SOURCE_REPLACEMENT}|g" > _job.xml
		java -jar jenkins-cli.jar -s ${JENKINS} -auth ${LOGIN}:${PASSWORD} create-job "${job_name}" < _job.xml
	fi
done

