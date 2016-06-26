#!/bin/ksh
##############################################################################
# Script:   viosbackup.ksh
# Author:   Glenn Robinson
# Date:     June 2015
#
# Script to automate vios backup to nfs share
#
# Usage:
# ./viosbackup.ksh
# OR
# ./viosbackkup.ksh -msksysb
#
# Note that the backupios command has two formats:
#
# By specifying -mksysb on the backupios command you will need not be able to use the mksysb for
# recovery by NIM or the HMC installios command unless you manually create a SPOT for the mksysb file
#
# If you do NOT specify -mksysb on the backupios command then the SPOT is created automatically
# which allows you to use NIM or HMC installios for recovery without any additional processing
#
##############################################################################
DATE=$(date +%Y'-'%m'-'%d)
LOG=${0}_${DATE}.out
exec 2>${LOG}
# Set verbose debug
# set -x
#
# Set Variables
#
typeset -i RETAIN_LOGS=7
FQHOST=`hostname`
HOST=${FQHOST%%.*}
MOUNTDIR=/mnt
BACKUPDIR=${MOUNTDIR}/backup/${HOST}
NFSHOST=MY_NFS_SERVER
NFSSHARE=/export/vios
FILENAME=${BACKUPDIR}/${HOST}_${DATE}.mksysb
CLUSTER=$(/usr/ios/cli/ioscli cluster -list|grep CLUSTER_NAME|awk '{ print $2 }')
# If no parameter was passed then do not use -mksysb when executing the backupios command
if [ $# -eq 0 ]
then
        MKSYSB=false
else
        MKSYSB=true
fi
# Initialise the log file
echo ${DATE} > ${LOG}
#
# Check the mount point exists (if run for the first time it may not)
#
if [[ ! -d ${MOUNTDIR} ]]
then
        print "\n${MOUNTDIR} mount point does not exist - creating \n" >> ${LOG}
        mkdir -m 777 -p ${MOUNTDIR}
else
        print "\n${MOUNTDIR} mount point exists \n" >> ${LOG}
fi
#
# Check the NFS mounts
#
RC_NFS=0
if [[ ! -d ${BACKUPDIR} ]]
then
        print "\nThe directory is not mounted, attempting to mount." >> ${LOG}
        nfso -o nfs_use_reserved_ports=1      # Required if "vmount: Operation not permitted" error occurs when trying to mount the share
        mount ${NFSHOST}:${NFSSHARE} ${MOUNTDIR}
else
        print "\n${MOUNTDIR} File System is already mounted, proceeding with backup" >> ${LOG}
fi
RC_NFS=$(echo $?)
if [[ RC_NFS -ne 0 ]]
then
        print "\nMounting the NFS share failed. Exiting backup procedure" >> ${LOG}
        exit
else
        print "\nMount of NFS share successful. Continuing with backup" >> ${LOG}
fi
#
# Backup VIOS
#
# Clean up old viosbr files
print "\nClean up old viosbr files > ${RETAIN_LOGS} days old" >> ${LOG}
find /home/padmin/cfgbackups -type f -mtime +${RETAIN_LOGS} | /usr/bin/xargs rm
# Clean up old log files
print "\nClean up old log files > ${RETAIN_LOGS} days old" >> ${LOG}
find /home/padmin/ -type f -mtime +${RETAIN_LOGS} -name "viosbackup*.out"| xargs rm
# Cleanup old backupios mksysb files > ${RETAIN_LOGS} days old
print "\nCleaning up old .mksysb files > ${RETAIN_LOGS} days old" >> ${LOG}
print "\nThis may take some time to complete" >> ${LOG}
# Check to see if there are any mksysb folders for this vios on the NFS server
# If the backups are saved with the SPOT file they will be stored in directories
# Recurse through the backups directories to to be deleted making sure all files are removed
TOPLEVEL=""
if [[ $(ls -dl ${BACKUPDIR}/${HOST}*|grep ^d|wc -l) -gt 0 ]]
then
        ls -dl ${BACKUPDIR}/${HOST}*|grep ^d|awk '{ print $9 }'| while read DIR
        do
                if [[ $(find ${DIR} -type f -name *_mksysb -mtime ${RETAIN_LOGS} | xargs echo |wc -l) -gt 0 ]]
                then
                        TOPLEVEL=${DIR}
                        ls -R ${DIR}|grep :$|sort|sed 's/.$/\/*/'| while read SUBDIR
                        do
                                print "\nDeleting contents of ${SUBDIR}" >> ${LOG}
                                rm -f ${SUBDIR}
                        done
                fi
                if [[ ! -z ${TOPLEVEL} ]]
                then
                        print "\nDeleting top level directory ${TOPLEVEL}" >> ${LOG}
                        rm -fR ${TOPLEVEL}
                fi
        done
fi
# Backup additional configuration elements (these will be within the mksysb taken later)
#
print "\nCreate listings of additional configuration elements" >> ${LOG}
/usr/ios/cli/ioscli lsmap -all > /home/padmin/mksysb/${HOST}_lsmap_scsi.out
/usr/ios/cli/ioscli lsmap -all -npiv > /home/padmin/mksysb/${HOST}_lsmap_npiv.out
/usr/ios/cli/ioscli lsmap -all -net > /home/padmin/mksysb/${HOST}_lsmap_net.out
/usr/ios/cli/ioscli viosecure -firewall view > /home/padmin/mksysb/${HOST}_firewall.out
lsdev | grep ^ent > /home/padmin/mksysb/${HOST}_lsdev_ent.out
ifconfig -a > /home/padmin/mksysb/${HOST}_ifconfig.out
lsattr -El inet0 > /home/padmin/mksysb/${HOST}_inet0.out
netstat -rn > /home/padmin/mksysb/${HOST}_netstat_rn.out
netstat -in > /home/padmin/mksysb/${HOST}_netstat_in.out
cat /etc/hosts > /home/padmin/mksysb/${HOST}_hosts.out
cat /etc/resolv.conf > /home/padmin/mksysb/${HOST}_resolv.out
cat /etc/netsvc.conf | grep -v '^#' > /home/padmin/mksysb/${HOST}_netsvc.out
cat /home/padmin/config/ntp.conf | grep -v '^#' > /home/padmin/mksysb/${HOST}_ntp_conf.out
cat /var/spool/cron/crontabs/root > /home/padmin/mksysb/${HOST}_crontab.out
lssrc -ls xntpd > /home/padmin/mksysb/${HOST}_xntpd.out
rules -o list > /home/padmin/mksysb/${HOST}_rules.out   ################################################ Requires VIOS 2.2.4.10 minimum
#
# Backup using viosbr command
#
RC_VIOSBR=0
/usr/ios/cli/ioscli viosbr -backup -file ${HOST}-${DATE}
RC_VIOSBR=$(echo $?)
if [[ ${RC_VIOSBR} -ne 0 ]]
then
        print "\nVIOSBR for $(date) FAILED \n" >> ${LOG}
else
        print "\nVIOSBR for $(date) COMPLETED SUCCESSFULLY \n" >> ${LOG}
fi
# Now backup SSP cluster
RC_VIOSBR=0
/usr/ios/cli/ioscli viosbr -backup -clustername ${CLUSTER} -file ${HOST}-${DATE}
RC_VIOSBR=$(echo $?)
if [[ ${RC_VIOSBR} -ne 0 ]]
then
        print "\nCluster VIOSBR for $(date) FAILED \n" >> ${LOG}
else
        print "\nCluster VIOSBR for $(date) COMPLETED SUCCESSFULLY \n" >> ${LOG}
fi
#
# Backup using backupios command
#
RC_MKSYSB=0
if ${MKSYSB}
then
# Run backupios without creating SPOT for NIM or HMC installios
        print "\nRunning backupios with -mksysb option"  >> ${LOG}
        /usr/ios/cli/ioscli backupios -file ${FILENAME} -nomedialib -mksysb
else
# Run backupios and create SPOT recource for NIM or HMC installios
        print "\nRunning backupios without -mksysb. NIM and HMC instalios prepared" >> ${LOG}
        /usr/ios/cli/ioscli backupios -file ${FILENAME} -nomedialib
fi
RC_MKSYSB=$(echo $?)
if [[ ${RC_MKSYSB} -ne 0 ]]
then
        print "\nMKSYSB for $(date) FAILED \n" >> ${LOG}
        # rm ${FILENAME}
else
        print "\nMKSYSB for $(date) COMPLETED SUCCESSFULLY \n" >> ${LOG}
fi
# Copy the log file to the share
cp ${LOG} ${BACKUPDIR}/${LOG}
#
# Unmount the NFS share
#
RC_UMOUNT=0
umount ${MOUNTDIR}
RC_UMOUNT=$(echo $?)
if [[ ${RC_UMOUNT} -ne 0 ]]
then
        print "\nNFS filesystem unmount FAILED \n" >> ${LOG}
else
        print "\nNFS filesystem unmount COMPLETED SUCCESSFULLY \n" >> ${LOG}
fi
exit
