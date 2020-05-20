#!/bin/bash
# This helper script dumps the workspace bundles and formats them according
# to the selection list criteria

aws workspaces describe-workspace-bundles --owner AMAZON | grep -E '^            "Description|BundleId' | sed 's/            "Description": "//' | tr '\n' $ | sed 's/", $            "BundleId": "/=/g' | sed 's/", \$/$/g' | tr $ '\n' | sort -k1,1 -t'=' | awk -F'=' '{printf "      - %s|%s\n", $1, $2}'
