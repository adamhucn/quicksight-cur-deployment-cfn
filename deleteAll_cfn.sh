### Powered by AWS Enterprise Support 
### Mail: tam-solution-costvisualization@amazon.com
### Version 1.0

REGIONCUR="us-east-1"

aws configure set aws_access_key_id $ACCESSKEY
aws configure set aws_secret_access_key $SECRETKEY
aws configure set default.region us-east-1

# Get the running profile
stsresult=`aws sts get-caller-identity`

# Get the Account ID by running profile
AccountID=`echo $stsresult | jq -r '.Account'`

# Set the default region, only valid in current script session or shell
CURRENTREGION=`aws configure get region`

# If has no default region, set it as us-east-1
if [ "$CURRENTREGION" = "" ]; then
	CURRENTREGION="us-east-1"
fi

DATASOURCEID="cur-datasource-id-"$REGIONCUR
DATASETID="cur-dataset-id-"$REGIONCUR
DASHBOARDID="cur-dashboard-id-"$REGIONCUR

# Delete resources created for CUR generated from global region
aws quicksight delete-dashboard --aws-account-id $AccountID --dashboard-id $DASHBOARDID --region $REGIONCUR
aws quicksight delete-data-set --aws-account-id $AccountID --data-set-id $DATASETID --region $REGIONCUR
aws quicksight delete-data-source --aws-account-id $AccountID --data-source-id $DATASOURCEID --region $REGIONCUR

# Delete resources created for CUR generated from China region
aws quicksight delete-dashboard --aws-account-id $AccountID --dashboard-id cn-$DASHBOARDID --region $REGIONCUR
aws quicksight delete-data-set --aws-account-id $AccountID --data-set-id cn-$DATASETID --region $REGIONCUR
aws quicksight delete-data-source --aws-account-id $AccountID --data-source-id cn-$DATASOURCEID --region $REGIONCUR
