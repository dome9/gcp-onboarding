#!/bin/bash

# Define the usage function of this script
usage() {
    echo "Usage: script.sh -e <endpoint> -o <onboarding type> -c <centralized project> -p <list of projects to onboard>"
}

# Parse the named arguments
while getopts ":s:p:" opt; do
    case ${opt} in
        s)
            SUBSCRIPTION_NAME=${OPTARG}
            ;;
        p)
            PROJECTS=${OPTARG}
            ;;
        \?)
            echo "Invalid option: -$OPTARG"
            usage
            exit 1
            ;;
        :)
            echo "Option -$OPTARG requires an argument."
            usage
            exit 1
            ;;
    esac
done
IFS=' ' read -ra PROJECTS_TO_ONBOARD <<< "$PROJECTS"

# sink creation in each onboarded project
for PROJECT_ID in "${PROJECTS_TO_ONBOARD[@]}"
do
	echo PROJECT_ID
done