#!/bin/ksh
#
# Display Ethernet statistics for SEA
#
#
#
 
FILE=/tmp/seastats
 
# Generate a work file with the stats
entstat -d $(lsdev |grep "Shared Ethernet"| awk '{ print $1 }')>$FILE
 
clear
 
# Print the first two lines
head -2 $FILE
 
echo "\nHA mode for this SEA"
awk /"High Availability Mode:"/ $FILE
 
echo "\nSEA current state"
awk /"   State:"/ $FILE| tr -d " "
 
echo "\nCurrent bridge mode for this SEA"
awk /"Bridge Mode:"/ $FILE
 
echo "\nPhysical adapter used by SEA:"
awk /"Real Adapter:"/ $FILE
 
echo "\nVirtual adapters using SEA:"
awk /"Virtual Adapter:"/ $FILE
 
echo "\nVLANs configured to use this SEA"
awk /"VLAN Tag IDs:"/ $FILE|grep -v None
 
echo "\nVLANs currently using this SEA"
awk /"VID shared"/ $FILE
 
echo "\n"
 
head -1 $FILE
 
rm $FILE
