# !ksh
DEBUG=""

customize_node_xml()
{
    NODEFILE=$1
    LOCAL_NODEFILE=$2
    TEMPNODEFILE="xml.temp1"
    TEMPFILE="xml.temp2"
    echo "<vios-backup>" > $TEMPNODEFILE
    sed -n '/<general>/,/<\/general>/p' $NODEFILE  >> $TEMPNODEFILE
    sed -n '/<cluster /,/<\/cluster>/p' $NODEFILE  >> $TEMPNODEFILE
    sed -n '/<vioCluster0>/,/<\/vioCluster0>/p' $NODEFILE  >> $TEMPNODEFILE
    echo "</vios-backup>"  >> $TEMPNODEFILE
    sed 's/<\/migrated>/& \<customized>1<\/customized>/' $TEMPNODEFILE > $TEMPFILE
    #Remove all other XML files
    rm *.xml
    cp "$TEMPFILE" "$LOCAL_NODEFILE"
    rm "$TEMPFILE"
    rm "$TEMPNODEFILE"
    if [ "$DEBUG" ]
    then
        cat $LOCAL_NODEFILE
    fi
}

#It collects the mirrored pool disks information from the system
getPoolDisks()
{
    bPOOLID=$1
    if [ "$DEBUG" ]
    then
      echo "Backup POOL_ID:$bPOOLID"
    fi

    NUM_POOL_PVS_FOUND=0
    cat /dev/null > $MY_PV_FILE
    for disk in `/usr/sbin/pooladm -I pool querydisk -a 2>/dev/null |egrep 'Name:|Pool UID:' |awk -v POOLID=\$bPOOLID '/Name:/{FS="/"; DISK=\$3}/Pool UID:/{FS=" "; SYSPOOLID=\$3} {if(POOLID==SYSPOOLID){printf("%s\n", DISK)}; SYSPOOLID=0}' |sort -u`
    do
      lsattr -El $disk -a unique_id -F value >> $MY_PV_FILE
      ((NUM_POOL_PVS_FOUND = $NUM_POOL_PVS_FOUND + 1))
    done

    if [ "$NUM_POOL_PVS_FOUND" == "0" ]
    then
      echo "Could not find any disk with the matching backup POOL_ID:$bPOOLID"
      exit 2 
    fi

    if [ "$DEBUG" ]
    then
      echo "Number of Pool PVs found: $NUM_POOL_PVS_FOUND"
      echo "PV file contents:"
      cat $MY_PV_FILE
    fi
}

extract_general_xml()
{
    orgfile=$1
    newfile=$2
    tempfile="tfile.xml"
    done=0
    cat /dev/null > $tempfile
    while read line
    do
        echo "$line" | grep "clCommMode" > /dev/null
        if [ $? -eq 0 ]
        then
            for word in $line
            do
                echo "$word" | grep "clCommMode" > /dev/null
                if [ $? -eq 0 ]
                then
                    lword=`echo "$word" | cut -d '<' -f1`
                    done=1
                    break
                else
                    myline="$myline $word"
                fi
            done
    
        else
            echo "$line" >> "$tempfile"
        fi
        if [ "$done" -eq 1 ]
        then
            echo "$myline $lword" >> "$tempfile"
            break;
        fi
    done  < "$orgfile"
    cat "$tempfile" > "$newfile"
    rm "$tempfile" > /dev/null
}
########## Execution starts here ###################

USAGE="\nUSAGE: customize_ssp_backup <backup_file> <hostnames_file> [PoolDisks_file]\n"
HLP="\tbackup_file \t-Backup filename captured on primary site.\n\thostnames_file \t-Filename with the new hostname(s) on seconday site\
\n\tPoolDisks_file \t-Filename with the mirrored disks' unique_ids.\n\t\t\t If this command runs on the VIOS system that has access to the mirrored LUNs,\n\t\t\t passing this information is optional\n"

if [ "$1" = "-h" ] || [ "$1" = "-H" ]
then
  echo "$USAGE"
  echo "$HLP"
  return 0
fi

if [ $# -lt 2 ]
then
  echo "$USAGE"
  return 1
fi

BACKUP_FILE=$1
HOSTS_FILE="$PWD/$2"
PV_FILE="$3"
TEMPDIR="temp"

if [ "$DEBUG" ]
then
    echo "backupfile=$BACKUP_FILE, hostfile=$HOSTS_FILE, pvfile=$PV_FILE"
fi

if [ -z "$BACKUP_FILE" ] || [ -z "$HOSTS_FILE" ]
then
  echo "Missing argument for BACKUP/NODENAMES/DISK LIST file"
  return 1
fi

#Uncompress backup file
mkdir -p $TEMPDIR
cd "$TEMPDIR"
gzip -dc ../$BACKUP_FILE | tar -xvf -  >/dev/null
if [ $? -ne 0 ]
then
  echo "Error uncompressing given backup file $BACKUP_FILE"
  return 2
fi

#Make an XML representing local node
MTM=`/usr/lib/methods/vioscmd -mtm`
LPARID=`/usr/lib/methods/vioscmd -part`
NODEFILE=`ls *.xml |tail -1`
CLUSTER_NAME=`grep "CuAt name=\"clustername\"" $NODEFILE |cut -d '"' -f4`
BKP_POOLID=`grep "CuAt name=\"default_pool\"" $NODEFILE |cut -d '"' -f4`
LOCAL_NODEFILE="${CLUSTER_NAME}MTM${MTM}P${LPARID}.xml"
BACKUP_FILE_NEW=`echo $BACKUP_FILE|cut -d . -f1`
BACKUP_FILE_NEW="${BACKUP_FILE_NEW}_NEW.${CLUSTER_NAME}.tar"
MY_PV_FILE="MyDiskListFile"

if [ -z "$PV_FILE" ]
then
    getPoolDisks "$BKP_POOLID"
    PV_FILE=$MY_PV_FILE
    cp "$MY_PV_FILE" ..
fi

if [ "$DEBUG" ]
then
    echo "MTM=$MTM, ID=$LPARID, nodefile=$NODEFILE, clust=$CLUSTER_NAME, localnode=$LOCAL_NODEFILE"
    echo "newbackup=$BACKUP_FILE_NEW"
fi

customize_node_xml "$NODEFILE" "$LOCAL_NODEFILE"

CLUST_CONF_FILE=`ls ${CLUSTER_NAME}DB/*/VIOCLUST.xml`
CLUST_CONF_FILE="$PWD/$CLUST_CONF_FILE"
CLUST_CONF_FILE_NEW=`echo $CLUST_CONF_FILE| sed 's/VIOCLUST/VIOCLUST2/g'`

if [ "$DEBUG" ]
then
    echo "CLUSTER CONF FILE=$CLUST_CONF_FILE"
    echo "CLUSTER CONF FILE NEW=$CLUST_CONF_FILE_NEW"
fi

TAG_PV_START="<Pool><Tier><FailureGroup>"
TAG_PV_END="</FailureGroup></Tier></Pool>"
TAG_END="</Cluster></Backup></VIO>"

extract_general_xml "$CLUST_CONF_FILE" "$CLUST_CONF_FILE_NEW"

#Read hostnames from user given file and create a conf file
#Get each hostname from user given file, and insert in XML
while read NODE
do
  echo "\t<Partition hostname=\"$NODE\"/>" >> $CLUST_CONF_FILE_NEW
done < $HOSTS_FILE

echo "\t$TAG_PV_START" >> $CLUST_CONF_FILE_NEW

#Get each pool disk unique_id from user given file, and insert in XML
while read DISK
do
  echo "\t\t<PhysicalVolume udid=\"$DISK\" name=\"\" usage=\"0\" capacity=\"\" description=\"\"/>" >> $CLUST_CONF_FILE_NEW
done < ../$PV_FILE

echo "\t$TAG_PV_END" >> $CLUST_CONF_FILE_NEW
echo "$TAG_END" >> $CLUST_CONF_FILE_NEW

#copy the new config file as original conf file 
cp $CLUST_CONF_FILE_NEW $CLUST_CONF_FILE
cmdstatus=$?

if [ $cmdstatus -eq 0 ]
then
  tar -cvf "$BACKUP_FILE_NEW" * >/dev/null
  if [ $? -eq 0 ]
  then
    gzip "$BACKUP_FILE_NEW"
    if [ $? -eq 0 ]
    then
      cp "$BACKUP_FILE_NEW".gz ..
      echo "New configuration file created successfully: $BACKUP_FILE_NEW.gz\n"
    fi
  fi
fi

#remove temp space
cd ..
if [ "$DEBUG" == "" ]
then
  rm -rf "$TEMPDIR"
fi
