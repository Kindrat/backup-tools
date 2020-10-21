# backup-tools
Scripts to back up dev services

## Jenkins
Save and restore JOb definitions through Jenkins CLI
Missing:
* ENV variables migration
* View migration

## Gitlab
Made to migrate from gitlab to gitlab using REST APIs
Missing:
* Users migration
* Lots of validations (expecting to move to a brand-new instance without retries - otherwise cleanup before trying again)
