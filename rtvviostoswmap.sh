
FABA=192.168.70.155
FABB=192.168.70.156
SWUSER=admin
SWPWD=S@nSt0r@g3

# List the managed systems we are connected to
for SYS in $(lssyscfg -r sys -F name)
do
# List the VIOS LPARs on the current managed system	
	for VIOS in $(lssyscfg -m $SYS -r lpar -F name lpar_env|fgrep vioserver|sed 's/vioserver//')
	do
# List the physical Fibre Channel adapters in the current VIOS
		viosvrcmd -m $SYS -p $VIOS -c lsdev|grep ^fcs|grep Available| while read FCS REST
		do 
			printf ${SYS}"\t"${VIOS}"\t"${FCS}"\t"
# Get the wwn of the current adapter
# Format the WWN with colons
# Replace upper case characters with lower case characters so that the WWN is compatible with the format used in the SAN switces
			WWN=$(viosvrcmd -m ${SYS} -p ${VIOS} -c "lsdev -vpd -dev ${FCS}"|grep "Network Address"|tail --bytes 17|sed 's/../&:/g;s/:$//'|sed -e 's/\(.*\)/\L\1/')
			printf $WWN"\n"
			###ssh admin@$FABA "nodefind ${WWN}"|grep "Port Index"
		done
	done
done


