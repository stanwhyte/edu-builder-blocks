#!/bin/bash
# This script will recursively pull all of the submodules (updating as 
# appropriate) and put the corresponding files into the external folder.

display_usage() { 
  echo -e "\nUsage:\nbuild-submodules.sh -d DIRECTORY\n" 
  exit 0
} 

while getopts "d:h" option; do
  case ${option} in
    d) DIR=$OPTARG;;
    h) display_usage;;
  esac
done

# In the event that the directory wasn't populated, derive it based on the 
# location of the current script.  This assumes that the scripts folder is
# located directly off the root of the project.
if [ -z "$DIR" ] 
then 
  DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )/.."
fi 

# Remove and re-initialize the submodules and external folders
# rm -rf $DIR/submodules
# rm -rf $DIR/external

# This command will re-initialize the submodules
cd $DIR
git submodule update --merge --remote --init --recursive

# This rsync command will copy the submodule content to the external folder
rsync -a --exclude='.*' $DIR/submodules/ $DIR/external
