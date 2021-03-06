#!/bin/bash
 
# source the ciop functions (e.g. ciop-log)
source ${ciop_job_include}

# define the exit codes
SUCCESS=0
ERR_MASTER=10
ERR_SLAVE=20
ERR_EXTRACT=30
ERR_ADORE=40
ERR_PUBLISH_RES=50
ERR_PUBLISH_PNG=60

# add a trap to exit gracefully
function cleanExit ()
{
  local retval=$?
  local msg=""
	
  case "$retval" in
		$SUCCESS) msg="Processing successfully concluded";;
		$ERR_MASTER) msg="Failed to retrieve the master product";;
     $ERR_SLAVE) msg="Failed to retrieve the slave product";;
$ERR_EXTRACT) msg="Failed to retrieve the extract the vol and lea";;
		$ERR_ADORE) msg="Failed during ADORE execution";;
		$ERR_PUBLISH_RES) msg="Failed results publish";;
		$ERR_PUBLISH_PNG) msg="Failed results publish quicklooks";;
		*) msg="Unknown error";;
  esac

  [ "$retval" != "0" ] && ciop-log "ERROR" "Error $retval - $msg, processing aborted" || ciop-log "INFO" "$msg"
#  rm -rf $TMPDIR	
  exit $retval
}
trap cleanExit EXIT

# shorter temp path 
TMPDIR="/tmp/`uuidgen`"

# creates the adore directory structure
ciop-log "INFO" "creating the directory structure"
mkdir -p $TMPDIR
mkdir -p $TMPDIR/process
cd $TMPDIR/process

settings="`ciop-getparam settings`"
ciop-log "INFO" "Additional settings for adore: $settings"

echo "$settings" | tr "," "\n" | sed 's/^/settings apply -r -q /' > $TMPDIR/process/settings


master_ref="`ciop-getparam master`"
slave_ref="`cat`"

ciop-log "INFO" "Retrieving master"
master="`echo $master_ref | ciop-copy -U -O $TMPDIR -`"
[ $? -ne 0 ] && exit $ERR_MASTER

ciop-log "INFO" "Retrieving slave"
slave="`echo $slave_ref | ciop-copy -U -O $TMPDIR -`"
[ $? -ne 0 ] && exit $ERR_SLAVE

ciop-log "INFO" "Extract lea and vol"

# extract the vol and lea from the archive
$_CIOP_APPLICATION_PATH/adore/bin/extract_tsx.sh $master $slave
[ $? -ne 0 ] && exit $ERR_EXTRACT

# free up some space
rm -f $master $slave

dm="`find data -type d -name "master*"`"
mvol="`find $dm -name "*.cos"`"
mlea="`find $dm -name "*.xml"`"

sm="`find data -type d -name "slave*"`"
svol="`find $sm -name "*.cos"`"
slea="`find $sm -name "*.xml"`"

ciop-log "INFO" "Launching adore for TSX"
export ADORESCR=/opt/adore/scr
export PATH=/usr/local/bin:/opt/adore/scr:$PATH
adore "p $_CIOP_APPLICATION_PATH/adore/libexec/ifg.adr $mvol $svol $mlea $slea $_CIOP_APPLICATION_PATH/adore/etc/tsx.steps"

[ $? -ne 0 ] && exit $ERR_ADORE

ciop-publish -m $TMPDIR/process/*.int
res=$?
[ $res -ne 0 ] && exit $ERR_PUBLISH_RES

ciop-publish -m $TMPDIR/process/adoretsx.list

# publish the quicklooks
ciop-publish -m $TMPDIR/process/*.png
res=$?
[ $res -ne 0 ] && exit $ERR_PUBLISH_PNG
 
ciop-log "INFO" "Done"
