#!/bin/ksh
# makessplu.ksh - Create a set of LUs in a storage pool
# Usage - makessplu start_lu_number end_lu_number lpar_name size_in_GB cluster_name storage_pool_name
# e.g. makessplu.ksh 1 183 mylpar 140 cl_mycluster sp_mypool
# Will create 183 LUs each 140GB and named mylpar_L001-L183 in storage pool sp_mypool which is in cluster cl_mycluster

typeset -Z3 x
i=$1
host=$3
size=$4
cluster=$5
stgpool=$6
while [[ i -le $2 ]]; do
x=$i
lu=$host"_L"$x
      /usr/ios/cli/ioscli lu -create -clustername $cluster -sp $stgpool -lu $lu -size $size
((i+=1))
done
