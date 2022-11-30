# !/bin/bash
output_to_file=true
while getopts ":t:u:" opt; do
  case $opt in
    t) output_to_file=false
    ;;
    u) username=$OPTARG
    ;;
    \?) echo "Invalid option -$OPTARG" >&2
    exit 0;
    ;;
  esac
done

if [ $username ]
then
  echo "Org Name/Alias: ${username}" > .local/lastTestResult.txt
  echo ""  >> .local/lastTestResult.txt
else
  echo "Org Name/Alias: default" > .local/lastTestResult.txt
  echo ""  >> .local/lastTestResult.txt
fi

if [ $username ]
then
  result=$(sfdx force:data:soql:query -q "SELECT Id, Status FROM AsyncApexJob WHERE JobType = 'TestRequest' ORDER BY CreatedDate DESC LIMIT 1" -u $username --json)
else
  result=$(sfdx force:data:soql:query -q "SELECT Id, Status FROM AsyncApexJob WHERE JobType = 'TestRequest' ORDER BY CreatedDate DESC LIMIT 1" --json)
fi

jobId=$(echo ${result} | jq -r ".result.records[0].Id")
jobStatus=$(echo ${result} | jq -r ".result.records[0].Status")

echo "Getting results for Test Execution $jobId ($jobStatus)"

if [ "$jobStatus" != "Completed" ] ; then
    echo "Warning: Test execution not finished yet. [Status = $jobStatus]"
fi

echo "Test Id: ${jobId}" >> .local/lastTestResult.txt
echo "Test Status: ${jobStatus}" >> .local/lastTestResult.txt
echo ""  >> .local/lastTestResult.txt

if [ $username ]
then
  sfdx force:data:soql:query -q "SELECT Count(Id) TestClasses FROM ApexTestQueueItem WHERE ParentJobId = '${jobId}'" -u $username >> .local/lastTestResult.txt
else
  sfdx force:data:soql:query -q "SELECT Count(Id) TestClasses FROM ApexTestQueueItem WHERE ParentJobId = '${jobId}'">> .local/lastTestResult.txt
fi
echo ""  >> .local/lastTestResult.txt

if [ "$output_to_file" = true ] ; then
    echo "Summary:" >> .local/lastTestResult.txt
    echo "========" >> .local/lastTestResult.txt
    if [ $username ]
    then
      sfdx force:data:soql:query -q "SELECT Outcome, COUNT(Id) Message FROM ApexTestResult WHERE AsyncApexJobId = '${jobId}' Group By Outcome" -u $username >> .local/lastTestResult.txt
    else
      sfdx force:data:soql:query -q "SELECT Outcome, COUNT(Id) Message FROM ApexTestResult WHERE AsyncApexJobId = '${jobId}' Group By Outcome" >> .local/lastTestResult.txt
    fi
    echo "" >> .local/lastTestResult.txt
    echo "Failures:" >> .local/lastTestResult.txt
    echo "========" >> .local/lastTestResult.txt
    if [ $username ]
    then
      sfdx force:data:soql:query -q "SELECT ApexClass.Name, MethodName, Outcome, Message FROM ApexTestResult WHERE Outcome != 'Pass' AND AsyncApexJobId = '${jobId}' ORDER BY ApexClass.Name" -u $username >> .local/lastTestResult.txt
    else
      sfdx force:data:soql:query -q "SELECT ApexClass.Name, MethodName, Outcome, Message FROM ApexTestResult WHERE Outcome != 'Pass' AND AsyncApexJobId = '${jobId}' ORDER BY ApexClass.Name" >> .local/lastTestResult.txt
    fi
    code -r .local/lastTestResult.txt
else
    if [ $username ]
    then
      sfdx force:data:soql:query -q "SELECT ApexClass.Name, MethodName, Outcome, Message FROM ApexTestResult WHERE Outcome != 'Pass' AND AsyncApexJobId = '${jobId}' ORDER BY ApexClass.Name" -u $username
    else
      sfdx force:data:soql:query -q "SELECT ApexClass.Name, MethodName, Outcome, Message FROM ApexTestResult WHERE Outcome != 'Pass' AND AsyncApexJobId = '${jobId}' ORDER BY ApexClass.Name"
    fi
fi