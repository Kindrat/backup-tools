#!/bin/bash
###################################################################
#Script Name	: restore.sh
#Description	: Restores a copy of repos to Gitlab
#Args         : Hardcoded currently
#Author       : @Kindrat
#Email        : legioner.alexei@gmail.com
###################################################################

# Prints a string with current date to stdout - e.g. log message
function log() {
	echo -e "$(date)\t$@"
}

# Join array ($2) with delimiter char ($1)
# Return: single string
function joinBy() { 
	local IFS="$1"
	shift
	echo "$*"
}

# Checks if array ($2) contains provided element ($1)
# Return: true (0) if array contains element, otherwise - false (1)
function containsElement() {
  local e match="$1"
  shift
  for e; do [[ "$e" == "$match" ]] && return 0; done
  return 1
}

# Target gitlab URL
GITLAB=https://gitlab.example.com/
# User API token
TOKEN=1ccn69QxZx4dQYhE1Vpp
SOURCE_DIR=/backup
declare -A ID_BY_GROUP
declare -A GROUP_BY_PATH

log "Fetching local repos"
# All directories under backup dir
REPOS=$(ls -d ${SOURCE_DIR}*/)
# Declaring array to fill with group names, missing on target Gitlab
NONEXISTING_GROUPS=()
DELIMITER=__

for repo in ${REPOS}; do
	log "Checking ${repo}"
	# Just name of repo dir with group hierarchy
	name=$(basename "${repo}")
	name_parts=($(echo ${name} | tr "${DELIMITER}" "\n"))
	# if repo contains some group names in dir name lets check them - array with names parts las length more than 1
	if [[ ${#name_parts[@]} -gt 1 ]]; then
	  # starting from single first element (root group) adding parts one-by-one and check if we need to create such group
		for i in $(seq 1 $((${#name_parts[@]}-1))); do
		  # slicing name parts for group data only
			testing_part=("${name_parts[@]:0:${i}}")
			# joining parts to form subgroup full name
			testing_group=$(joinBy / "${testing_part[@]}")
			#log "Checking group: ${testing_group}"
			# no caching - just retrieve all available groups for each check
			raw_groups=$(curl --header "PRIVATE-TOKEN: ${TOKEN}" -s "${GITLAB}api/v4/groups?simple=true&all_available=true")
			# extracting path from metadata JSON
			groups=$(echo "${raw_groups}" | jq -r '.[].full_path')
			# check if existing group paths contain current test subject
			if $(containsElement "${testing_group}" ${groups[@]}); then
			  # now if we found the group it may be later used as a parent for subgroups we'll get in next iterations,
			  # so save ID of existing group to associative array by group full path
				group_id=$(echo "${raw_groups}" | jq -c "map(select(.full_path==\""${testing_group}"\")) | .[] .id")
				#log "Skipping existing group: ${testing_group} : ${group_id}"
				ID_BY_GROUP[${testing_group}]=${group_id}
			else
				log "Add group to creation queue: ${testing_group}"
				# adding group to array for further creation as well as updating cache with group name by its full path
				NONEXISTING_GROUPS+=("${testing_group}")
				GROUP_BY_PATH["${testing_group}"]=${name_parts[$((${i}-1))]}
			fi
		done	
	fi
done

# Some groups could be added multiple times, so sorting them and removing duplicates. Sorting will guarantee that
# subgroups will be processed after theie parents
SORTED_UNIQUE_NONEXISTENT_GROUPS=($(echo "${NONEXISTING_GROUPS[@]}" | tr ' ' '\n' | sort -u | tr '\n' ' '))
if [[ ${#SORTED_UNIQUE_NONEXISTENT_GROUPS[@]} -gt 1 ]]; then
	log "Groups to create: ${SORTED_UNIQUE_NONEXISTENT_GROUPS[@]}"
fi

for group in ${SORTED_UNIQUE_NONEXISTENT_GROUPS[@]}; do
	name_parts=($(echo ${group} | tr "/" "\n"))
	parent_ref=""
	path_parts=${#name_parts[@]}
	# check if we are processing subgroup and prepare a piece of request payload with parent group ID
	if [[ ${path_parts} -gt 1 ]]; then
			parent_path=${name_parts[@]:0:$((${path_parts}-1))}
			parent_group=$(joinBy / "${parent_path[@]}")
			parent_ref=', "parent_id":'"${ID_BY_GROUP[${parent_group}]}"' '
	fi
	local_name="${GROUP_BY_PATH[${group}]}"
	# Minimal payload to make default private group
	payload='{"path": "'${local_name}'", "name": "'${local_name}'", "visibility": "private" '${parent_ref}'}'
	log "Creating group ${group}: ${payload}"
	# Saving newly created group ID to cache to use for its subgroups if there will be any
	id=$(curl --header "PRIVATE-TOKEN: ${TOKEN}" --header "Content-Type: application/json" -s --data ' '"${payload}"' ' "${GITLAB}api/v4/groups" | jq -r '.id')
	ID_BY_GROUP[${group}]=${id}
	log "Created group ${group} with ID ${id}"
done

# when groups are created it's time to create project and upload code
for repo in ${REPOS}; do
	name=$(basename "${repo}")
	name_parts=($(echo ${name} | tr "${DELIMITER}" "\n"))
	project_name=${name_parts[$((${#name_parts[@]}-1))]}
	namespace=""
	path_parts=${#name_parts[@]}
	# if project is under some group, we need to get group ID and pass as namespace ID
	if [[ ${path_parts} -gt 1 ]]; then
			parent_path=(${name_parts[@]:0:$((${path_parts}-1))})
			parent_group=$(joinBy / "${parent_path[@]}")
			namespace=', "namespace_id":'"${ID_BY_GROUP[${parent_group}]}"' '
	fi
	payload='{"name": "'${project_name}'", "visibility": "private", "auto_devops_enabled": false'${namespace}'}'
	log "Creating project ${project_name}: ${payload}"
	ssh_url_to_repo=$(curl --header "PRIVATE-TOKEN: ${TOKEN}" --header "Content-Type: application/json" -s --data ' '"${payload}"' ' "${GITLAB}api/v4/projects" | jq -r '.ssh_url_to_repo')
	cd ${repo}
	git remote set-url origin "${ssh_url_to_repo}"
	log "Uploading to ${ssh_url_to_repo}"
	git push --all origin
	git push --tags origin
	cd -
done


