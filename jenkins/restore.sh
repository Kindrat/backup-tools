#!/bin/bash
###################################################################
#Script Name	: restore.sh
#Description	: Restores a copy of job configurations to new Jenkins instance
#Args         : Hardcoded currently
#Author       : @Kindrat
#Email        : legioner.alexei@gmail.com
###################################################################
set -e

# Prints a string with current date to stdout - e.g. log message
function log() {
	echo -e "$(date)\t$@"
}

# Checks if array ($2) contains provided element ($1)
# Return: true (0) if array contains element, otherwise - false (1)
function containsElement() {
  local e match="$1"
  shift
  for e; do [[ "$e" == "$match" ]] && return 0; done
  return 1
}

# Jenkins to restore backup to
JENKINS=https://new.jenkins.example.com
# Migrating CVS also from old to new URLs.

# Old CVS (Gitlab) utr + namespace
INITIAL_SOURCE=gitlab.com:project
# New CVS (Gitlab) utr + namespace
SOURCE_REPLACEMENT=gitlab.example.com:project
LOGIN=admin_user
PASSWORD=test_password

log "Installing plugins"
# Collecting installed unique plugin names in alphabetical order to skip duplicate installations
INSTALLED_PLUGINS=$(java -jar jenkins-cli.jar -s ${JENKINS} -auth ${LOGIN}:${PASSWORD} list-plugins | awk '{print $1}' | sort)
# Reading file, created by backup.sh
PLUGINS=$(awk -e '{print $1}' _plugins | sort)
for plugin in ${PLUGINS}; do
	if $(containsElement ${plugin} ${INSTALLED_PLUGINS[@]}); then
		log "Skipping installed plugin ${plugin}"
	else
		log "Installing plugin ${plugin}"
		java -jar jenkins-cli.jar -s ${JENKINS} -auth ${LOGIN}:${PASSWORD} install-plugin "${plugin}"
		# No need to add plugins to ${INSTALLED_PLUGINS} as our queue contains only unique elements
		# Some will be installed twice (requests ignored silently on Jenkins side) as shared dependencies for
		# other plugins
	fi
done
log "Restoring credentials"
# Credentials saved by backup.sh. Loading to default namespace
java -jar jenkins-cli.jar -s ${JENKINS} -auth ${LOGIN}:${PASSWORD} import-credentials-as-xml "system::system::jenkins" < ./_credentials.xml
log "Restored credentials"
log "Restarting"
# Jenkins won't enable most of plugins till the restart
java -jar jenkins-cli.jar -s ${JENKINS} -auth ${LOGIN}:${PASSWORD} restart

# Pinging Jenkins after restart till it will return valid response
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

