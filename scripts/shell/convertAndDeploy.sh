# !/bin/bash

if [ $# -eq 1 ]
then
    sfdx force:source:convert --outputdir ../ConvertedFieloPIP --packagename FieloPIP &&

    sfdx force:mdapi:deploy --deploydir ../ConvertedFieloPIP --targetusername $1 -w 60
else
    echo "MISSING ORG ALIAS/USERNAME"
fi
