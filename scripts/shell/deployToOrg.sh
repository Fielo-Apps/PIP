# !/bin/bash

if [ $# -eq 1 ]
then
    sfdx force:source:deploy -p force-app -u $1 -l RunSpecifiedTests -r TestSimulator
else
    echo "MISSING ORG ALIAS/USERNAME"
fi
