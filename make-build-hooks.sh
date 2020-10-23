#!/bin/bash

set -e

function log() {
	echo -e "`date`\t$@"
}

function containsElement() {
  local e match="$1"
  shift
  for e; do [[ "$e" == "$match" ]] && return 0; done
  return 1
}

JENKINS=https://jenkins.example.com
LOGIN=admin_user
PASSWORD=1111111-fult0WOB

EXISTING_JOBS=$(java -jar jenkins-cli.jar -s ${JENKINS} -auth ${LOGIN}:${PASSWORD} list-jobs)

GITLAB=https://gitlab.example.com/
TOKEN=1ccn69QtttttQYhE1Vpp

for job in ${EXISTING_JOBS}; do
	log "Processing ${job}"
  job_metadata=$(java -jar jenkins-cli.jar -s ${JENKINS} -auth ${LOGIN}:${PASSWORD} get-job ${job})
  token=$(echo "${job_metadata}" | xq '/project/triggers/com.dabsquared.gitlabjenkins.GitLabPushTrigger/secretToken' | tr "\n" " " | sed 's/.*<secretToken>//g' | sed 's|</secretToken>.*||g' | sed 's|<results/>||g')
  if [[ ! -z "${token}" ]]; then 
  	log "Parsed hook token: ${token}"
  	project=$(echo "${job_metadata}" | xq '/project/scm/userRemoteConfigs/hudson.plugins.git.UserRemoteConfig/url' | tr "\n" " " | sed 's/.*<url>//g' | sed 's|</url>.*||g' | sed 's|.*:||g' | sed 's|\.git||g')
  	urlencoded_project=$(echo "${project}" | sed 's/\//%2F/g')
		gitlab_project=$(curl --header "PRIVATE-TOKEN: ${TOKEN}" -s "${GITLAB}api/v4/projects/${urlencoded_project}")
		project_id=$(echo "${gitlab_project}" | jq '.id')
  	if [[ "${job}" == *"_build-branch"* ]]; then
			payload='{"url": "'${JENKINS}'/project/'${job}'", "note_events": true, "merge_requests_events": true, "enable_ssl_verification": true, "id":'${project_id}', "token":"'${token}'"}'
			response=$(curl --header "PRIVATE-TOKEN: ${TOKEN}" --header "Content-Type: application/json" -s --data ' '"${payload}"' ' "${GITLAB}api/v4/projects/${project_id}/hooks")
  		log "Created branch hook: ${response}"
  	elif [[ "${job}" == *"_build-master"* ]]; then
			payload='{"url": "'${JENKINS}'/project/'${job}'", "push_events": true, "push_events_branch_filter": "master", "enable_ssl_verification": true, "id":'${project_id}', "token":"'${token}'"}'
			response=$(curl --header "PRIVATE-TOKEN: ${TOKEN}" --header "Content-Type: application/json" -s --data ' '"${payload}"' ' "${GITLAB}api/v4/projects/${project_id}/hooks")
  		log "Created master hook: ${response}"
   	fi
  fi
done

