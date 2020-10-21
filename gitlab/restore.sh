#!/bin/bash


function log() {
	echo -e "`date`\t$@"
}

function joinBy() { 
	local IFS="$1"
	shift
	echo "$*"
}

function containsElement() {
  local e match="$1"
  shift
  for e; do [[ "$e" == "$match" ]] && return 0; done
  return 1
}

GITLAB=https://gitlab.example.com/
TOKEN=1ccn69QxZx4dQYhE1Vpp
DEPLOY_USER=gitlab+deploy-token-010203
DEPLOY_TOKEN=qqqqq-AAAAAAAAAAAAAAAA
SOURCE_DIR=/backup
declare -A ID_BY_GROUP
declare -A GROUP_BY_PATH

log "Fetching local repos"

REPOS=$(ls -d ${SOURCE_DIR}*/)
NONEXISTING_GROUPS=()

for repo in ${REPOS}; do
	log "Checking ${repo}"
	name=$(basename ${repo})
	name_parts=($(echo ${name} | tr "__" "\n"))
	if [[ ${#name_parts[@]} -gt 1 ]]; then
		for i in $(seq 1 $((${#name_parts[@]}-1))); do
			testing_part=("${name_parts[@]:0:${i}}")
			testing_group=$(joinBy / "${testing_part[@]}")
			#log "Checking group: ${testing_group}"
			raw_groups=$(curl --header "PRIVATE-TOKEN: ${TOKEN}" -s "${GITLAB}api/v4/groups?simple=true&all_available=true")
			groups=$(echo "${raw_groups}" | jq -r '.[].full_path')
			if $(containsElement ${testing_group} ${groups[@]}); then
				group_id=$(echo "${raw_groups}" | jq -c "map(select(.full_path==\""${testing_group}"\")) | .[] .id")
				#log "Skipping existing group: ${testing_group} : ${group_id}"
				ID_BY_GROUP[${testing_group}]=${group_id}
			else
				log "Add group to creation queue: ${testing_group}"
				NONEXISTING_GROUPS+=("${testing_group}")
				GROUP_BY_PATH["${testing_group}"]=${name_parts[$((${i}-1))]}
			fi
		done	
	fi
done

SORTED_UNIQUE_NONEXISTENT_GROUPS=($(echo "${NONEXISTING_GROUPS[@]}" | tr ' ' '\n' | sort -u | tr '\n' ' '))
if [[ ${#SORTED_UNIQUE_NONEXISTENT_GROUPS[@]} -gt 1 ]]; then
	log "Groups to create: ${SORTED_UNIQUE_NONEXISTENT_GROUPS[@]}"
fi

for group in ${SORTED_UNIQUE_NONEXISTENT_GROUPS[@]}; do
	name_parts=($(echo ${group} | tr "/" "\n"))
	parent_ref=""
	path_parts=${#name_parts[@]}
	if [[ ${path_parts} -gt 1 ]]; then
			parent_path=${name_parts[@]:0:$((${path_parts}-1))}
			parent_group=$(joinBy / "${parent_path[@]}")
			parent_ref=', "parent_id":'"${ID_BY_GROUP[${parent_group}]}"' '
	fi
	local_name="${GROUP_BY_PATH[${group}]}"
	payload='{"path": "'${local_name}'", "name": "'${local_name}'", "visibility": "private" '${parent_ref}'}'
	log "Creating group ${group}: ${payload}"
	id=$(curl --header "PRIVATE-TOKEN: ${TOKEN}" --header "Content-Type: application/json" -s --data ' '"${payload}"' ' "${GITLAB}api/v4/groups" | jq -r '.id')
	ID_BY_GROUP[${group}]=${id}
	log "Created group ${group} with ID ${id}"
done

for repo in ${REPOS}; do
	name=$(basename ${repo})
	name_parts=($(echo ${name} | tr "__" "\n"))
	project_name=${name_parts[$((${#name_parts[@]}-1))]}
	namespace=""
	path_parts=${#name_parts[@]}
	if [[ ${path_parts} -gt 1 ]]; then
			parent_path=(${name_parts[@]:0:$((${path_parts}-1))})
			parent_group=$(joinBy / "${parent_path[@]}")
			namespace=', "namespace_id":'"${ID_BY_GROUP[${parent_group}]}"' '
	fi
	payload='{"name": "'${project_name}'", "visibility": "private", "auto_devops_enabled": false'${namespace}'}'
	log "Creating project ${project_name}: ${payload}"
	ssh_url_to_repo=$(curl --header "PRIVATE-TOKEN: ${TOKEN}" --header "Content-Type: application/json" -s --data ' '"${payload}"' ' "${GITLAB}api/v4/projects" | jq -r '.ssh_url_to_repo')
	cd ${repo}
	git remote set-url origin ${ssh_url_to_repo}
	log "Uploading to ${ssh_url_to_repo}"
	git push --all origin
	git push --tags origin
	cd -
done


