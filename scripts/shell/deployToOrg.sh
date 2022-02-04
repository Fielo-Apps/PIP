# !/bin/bash

if [ $# -eq 1 ]
then
    sfdx force:source:deploy -p force-app -u $1 && sfdx force:apex:test:run -y -t TestSimulator -u $1 && sfdx force:apex:test:run -y -t TestErrorService -u $1
else
    echo "MISSING ORG ALIAS/USERNAME"
fi
