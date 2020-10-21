#!/bin/bash


function log() {
	echo -e "$(date)\t$@"
}

GITLAB=https://gitlab.com/
TOKEN=test-01-02
DEPLOY_USER=gitlab+deploy-token-000000
DEPLOY_TOKEN=gggg-AAAAAAAAAAAAA
ROOT_GROUP=test_group
log "Fetching all Gitlab projects"
PAGE=1
PROJECT_URLS=$(curl --header "PRIVATE-TOKEN: ${TOKEN}" "${GITLAB}api/v4/projects?simple=true&page=${PAGE}&per_page=100&membership=true" | jq -r '.[].http_url_to_repo')
log "Got page ${PAGE} response"

while : ; do
	for url in ${PROJECT_URLS}; do
		log "Processing ${url}"
		if [[ ${url} == *"${ROOT_GROUP}"* ]]
		then
			auth_url=$(sed -e "s|https://|https://${DEPLOY_USER}:${DEPLOY_TOKEN}@|g" <<< ${url})
			target_dir=$(sed -e "s|${GITLAB}||g" <<< ${url} | sed -e "s|\.git||g" | sed -e "s|/|___|g")
			if [[ ! -d ${target_dir} ]]
			then
				log "Cloning ${auth_url} into ${target_dir}"
				git clone --progress ${auth_url} ${target_dir}		
			else
				log "Updating ${auth_url} in ${target_dir}"
				cd ${target_dir}
				git remote set-url origin ${auth_url}
				git pull --ff-only -v --all --progress
				cd -
			fi
		fi

	done

	let PAGE=${PAGE}+1
	PROJECT_URLS=$(curl --header "PRIVATE-TOKEN: ${TOKEN}" "${GITLAB}api/v4/projects?simple=true&page=${PAGE}&per_page=100&membership=true" | jq -r '.[].http_url_to_repo')
	[[ -z ${PROJECT_URLS} ]] && break
	log "Next page ${PAGE}"
done
