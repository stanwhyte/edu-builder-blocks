#!/bin/bash
# This script will recursively pull all of the submodules (updating as 
# appropriate) and put the corresponding files into the external folder.

display_usage() { 
  echo -e "Usage:\nbuild.sh -d /path/to/project" 
  exit 1
} 

echo

while getopts "d:h" option; do
  case ${option} in
    d) dir=$OPTARG;;
    h) display_usage;;
  esac
done

if [ -z "$dir" ]
then
  display_usage
fi

source $dir/scripts/_lib.sh

echo 'Initialize the submodules'
echo '-------------------------'
cd $dir
git submodule update --merge --remote --init --recursive
echo "Submodules initialized"

echo
echo 'Synchronize the submodules with the external folder'
echo '---------------------------------------------------'
rsync -a --exclude='.*' $dir/submodules/ $dir/external
