#!/bin/ksh
# mapssplu.ksh - Map a set of SSP LUs to a vhost
# Usage - mapssplu start_lu_number end_lu_number lpar_name vhost_adapter cluster_name storage_pool_name
# e.g. mapssplu.ksh 1 16 mylpar vhost0 cl_mycluster sp_mypool
# Will map LUs mylpar_L001-L016 to vhost0 using LUs mylpar_L001-L016 which are in storage pool sp_mypool contained in cluster cl_mycluster
typeset -Z3 x
i=$1
host=$3
vtd=$4
cluster=$5
stgpool=$6
while [[ i -le $2 ]]; do
x=$i
lu=$host"_L"$x
      /usr/ios/cli/ioscli lu -map -clustername $cluster -sp $stgpool -lu $lu -vadapter -vtd $vtd $lu
((i+=1))
done
