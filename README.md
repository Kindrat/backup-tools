# backup-tools
Scripts to back up dev services

* make-build-hooks.sh - create Gitlab webhooks for Jenkins Jobs with declared triggers

## Requirements:
* xq (pip3 install xq) to parse XML responses from Jenkins
* jq (apt install jq) to parse JSON responses from Gitlab 

## Jenkins
Save and restore Job definitions through [Jenkins CLI](https://www.jenkins.io/doc/book/managing/cli/). 
Missing:
* ENV variables migration
* View migration

**Backup**
1. Run ./backup.sh
2. All data would be in current dir

**Restore**
1. Run ./restore.sh from a dir with backup

## Gitlab
Made to migrate from gitlab to gitlab using [REST APIs](https://docs.gitlab.com/ee/api/api_resources.html)
Missing:
* Users migration
* Lots of validations (expecting to move to a brand-new instance without retries - otherwise cleanup before trying again)

**Backup**
1. Run ./backup.sh
2. All data would be in current dir

**Restore**
1. Run ./restore.sh from a dir with backup