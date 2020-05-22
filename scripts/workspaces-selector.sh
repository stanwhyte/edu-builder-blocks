#!/bin/bash
# This helper script dumps the workspace bundles and formats them according
# to the selection list criteria

aws workspaces describe-workspace-bundles --output text --owner AMAZON | grep BUNDLES | grep -v "Windows 7" | cut -f2,3
