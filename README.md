# backup-tools
Scripts to back up dev services

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