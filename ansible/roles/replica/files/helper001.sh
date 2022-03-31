#!/usr/bin/env bash
set -eo pipefail

command=$1
args="${@:2}"

LOGROOT=/data/ftproot-log
LOGSIZE=102400 # 100M

isDev() {
  [ "$APPCTL_ENV" == "dev" ]
}

log() {
  if [ "$1" == "--debug" ]; then
    isDev || return 0
    shift
  fi
  logger -S 5000 -t appctl --id=$$ -- "[cmd=$command args='$args'] $@"
}

execute() {
  local cmd=$1; log --debug "Executing command ..."
  [ "$(type -t $cmd)" = "function" ] || cmd=_$cmd
  $cmd ${@:2}
}

copyLog() {
  if [ ! -d $LOGROOT ]; then mkdir $LOGROOT; fi
  find /data/mongodb/ -name mongod.log.* -exec mv {} $LOGROOT \;
  cp -f /data/mongodb/mongod.log $LOGROOT
}

cleanLog() {
  rm -rf $LOGROOT/*
}

rotateLog() {
  /opt/mongodb/bin/mongo --authenticationDatabase admin --username qc_master --password $(cat /data/pitrix.pwd) --eval "db.adminCommand({logRotate:1})"
}

checkLog() {
  local sz=$(du -k /data/mongodb/mongod.log | cut -f1)
  if [ "$sz" -ge "$LOGSIZE" ]; then
    log "rotate the log file"
    rotateLog
  fi
}

# checkMongoVersion() {
#   local ver=$(/opt/mongodb/bin/mongo --authenticationDatabase admin --username qc_master --password $(cat /data/pitrix.pwd) --eval "db.version()" --quiet)
#   test $ver = "3.4.5"
# }

UPFOLDER="/data/upgrade-001"
BACKFOLDER="/data/backup-001"
CRONJOBFILE="/var/spool/cron/crontabs/root"

# log service
logService() {
  log "logService begin ..."
  # checkMongoVersion || return 1
  log "folders and files"

  cp /etc/vsftpd.conf $BACKFOLDER
  cp -f $UPFOLDER/vsftpd.conf /etc/
  log "restart vsftpd"
  systemctl restart vsftpd
  log "install cron job"
  cat $UPFOLDER/cronjob | crontab -
  log "cronjob done."
}

# rollback() {
#   log "downgrade begin ..."
#   log "folders and files"
#   rm -f /opt/mongodb/bin/helper001.sh
#   if [ -f $BACKFOLDER/vsftpd.conf ]; then
#     cp -f $BACKFOLDER/vsftpd.conf /etc/
#     log "restart vsftpd"
#     systemctl restart vsftpd
#   fi
#   log "remove cron job"
#   crontab -r || :
#   log "downgrade done"
# }

# CMDNAME="helper001.sh"
# makeImage() {
#   if [ ! -f $PWD/$CMDNAME ]; then echo "Please invoke the cmd from where $CMDNAME resident"; return 0; fi
#   cp -f $PWD/$CMDNAME /opt/mongodb/bin/
#   echo "copy $CMDNAME, done!"
#   cp -f $PWD/vsftpd.conf /etc/
#   echo "copy vsftpd.conf, done!"
#   cat $PWD/cronjob | crontab -
#   echo "install cron job, done!"
# }

execute $command $args