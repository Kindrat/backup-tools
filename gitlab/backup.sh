#!/bin/bash
###################################################################
#Script Name	: backup.sh
#Description	: Creates a copy of repos from Gitlab for migration to another instance
#Args         : Hardcoded currently
#Author       : @Kindrat
#Email        : legioner.alexei@gmail.com
###################################################################

# Prints a string with current date to stdout - e.g. log message
function log() {
	echo -e "$(date)\t$@"
}

# Source gitlab URL
GITLAB=https://gitlab.com/
# User API token to use for authorisation
TOKEN=test-01-02
# Gitlab does not allow to clone repos by user token - there should be a pair of deploy user-token per project or in parent group
DEPLOY_USER=gitlab+deploy-token-000000
DEPLOY_TOKEN=gggg-AAAAAAAAAAAAA

# Expecting all projects to be is single group
ROOT_GROUP=test_group
log "Fetching all Gitlab projects"
# Using pagination to bypass API restrictions for max elements in response
page=1
PROJECT_URLS=$(curl --header "PRIVATE-TOKEN: ${TOKEN}" "${GITLAB}api/v4/projects?simple=true&page=${page}&per_page=100&membership=true" | jq -r '.[].http_url_to_repo')
log "Got page ${page} response"

while : ; do
	for url in ${PROJECT_URLS}; do
		log "Processing ${url}"
		# Processing only projects under our root group
		if [[ ${url} == *"${ROOT_GROUP}"* ]]; then
		  # Enhancing project URL to include deploy creds
			auth_url=$(sed -e "s|https://|https://${DEPLOY_USER}:${DEPLOY_TOKEN}@|g" <<< ${url})
			# Extracting project name with path (project groups)
			target_dir=$(sed -e "s|${GITLAB}||g" <<< ${url} | sed -e "s|\.git||g" | sed -e "s|/|___|g")
			if [[ ! -d ${target_dir} ]]; then
				log "Cloning ${auth_url} into ${target_dir}"
				git clone --progress "${auth_url}" "${target_dir}"
			else
				log "Updating ${auth_url} in ${target_dir}"
				cd "${target_dir}"
				git remote set-url origin "${auth_url}"
				git pull --ff-only -v --all --progress
				cd -
			fi
		fi

	done

	let page=${page}+1
	PROJECT_URLS=$(curl --header "PRIVATE-TOKEN: ${TOKEN}" "${GITLAB}api/v4/projects?simple=true&page=${page}&per_page=100&membership=true" | jq -r '.[].http_url_to_repo')
	# Stop when there will be no more projects in response
	[[ -z ${PROJECT_URLS} ]] && break
	log "Next page ${page}"
done
