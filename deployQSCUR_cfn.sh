### Powered by AWS Enterprise Support 
### Mail: tam-solution-costvisualization@amazon.com
### Version 1.0


getCURDataSourceRegion() {
	# Construct the Athena query string to get one region value from CUR database
	QUERYSTRING="SELECT product_region FROM "\"$ATHENADB\".\"$ATHENATABLE\"" where length(product_region)>6 limit 1"

	# Get the Athena execution ID by running Athena query
	EXECUTIONID=`aws athena start-query-execution \
	--query-string "$QUERYSTRING" \
	--result-configuration "OutputLocation"="$OUTPUTBUCKET" | jq -r '.QueryExecutionId'`

	# Validate the query result every 2 seconds
	for curdatasourcetimer in {1..15}
	do
		EXECUTIONSTATUS=`aws athena get-query-execution --query-execution-id $EXECUTIONID | jq -r '.QueryExecution.Status.State'`
		
		# If qeury succeed, jump out the for loop, then check CUR data source region from query result
		if [[ $EXECUTIONSTATUS == "SUCCEEDED" ]]; then
			break

		elif [[ $EXECUTIONSTATUS == "RUNNING" ]]; then

			if [[ $curdatasourcetimer == 15 ]]; then
				echo Get CUR data source region timeout, please check your network connectivity and try again.
				exit
			fi

			echo Getting CUR data source region...

		# If query failed, exit this script
		else
			echo ""
			echo "Get CUR data source region failed! Please check your Athena configuration and IAM permissions."
			exit
		fi

		sleep 2s
	done

	# Get the region name from query result
	ATHENAQUERYRESULTS=`aws athena get-query-results --query-execution-id $EXECUTIONID | jq -r '.ResultSet.Rows[1].Data[0].VarCharValue'`

	# Get all region list and put it in an Array
	GLOBALREGIONLIST=($(aws ec2 describe-regions --query "Regions[].{Name:RegionName}" --output text))

	# Initialize the variable CURDATASOURCEREGION
	CURDATASOURCEREGION=""

	# Compare the region result with available regions to get region values
	for compareregion in "${GLOBALREGIONLIST[@]}";do 
		# Check if this region is in global region list
		if [ $compareregion = $ATHENAQUERYRESULTS ];then 

			# Get CURDATASOURCEREGIONSTRING value to define the name for datasource/dataset/dashboard
			CURDATASOURCEREGIONSTRING=""
			# Set a Region marker for global region
			CURDATASOURCEREGION="global"
			break

		# Check if this region is in China region list
		elif [ "$ATHENAQUERYRESULTS" = "cn-north-1" -o "$ATHENAQUERYRESULTS" = "cn-northwest-1" ];then 
			# Get CURDATASOURCEREGIONSTRING value to define the name for datasource/dataset/dashboard
			CURDATASOURCEREGIONSTRING="cn-"
			# Set a Region marker for Chinia region
			CURDATASOURCEREGION="China"
			break
		fi
	done

	# Get the lengh of region result
	CURDATASOURCEREGIONLENGTH=${#CURDATASOURCEREGION}
	
	# If region length lower than 1, need to update this tool
	if [ "$CURDATASOURCEREGIONLENGTH" -lt 1 ]; then
		echo "UNKNOWN region! Please try to run this script again or contact GCR Enterprise Support Cost Virsualization team to fix it."
		exit
	fi

	echo CUR created from $CURDATASOURCEREGION region.
}

getCURDateFormat(){
	# Construct the Athena query string to get the date format
	# Note: cannot add quote for ATHENADB and ATHENATABLE in describe command
	QUERYSTRING="describe "$ATHENADB.$ATHENATABLE" bill_billing_period_start_date;"

	# Get the Athena execution ID by running Athena query
	EXECUTIONID=`aws athena start-query-execution \
	--query-string "$QUERYSTRING" \
	--result-configuration "OutputLocation"="$OUTPUTBUCKET" | jq -r '.QueryExecutionId'`

	# Validate the query result every 2 seconds
	for curdateformattimer in {1..15}
	do
		EXECUTIONSTATUS=`aws athena get-query-execution --query-execution-id $EXECUTIONID | jq -r '.QueryExecution.Status.State'`
		
		# If qeury succeed, jump out the for loop, then check Date format from query result
		if [[ $EXECUTIONSTATUS == "SUCCEEDED" ]]; then
			break

		elif [[ $EXECUTIONSTATUS == "RUNNING" ]]; then
			if [[ $curdateformattimer == 15 ]]; then
				echo Get CUR date format timeout, please check your network connectivity and try again.
				exit
			fi

			echo Getting CUR date format...

		# If qeury failed, exit this script
		else
			echo ""
			echo "Get CUR date format failed! Please check your Athena configurations and IAM permissions."

			exit
		fi

		sleep 2s
	done

	# Get the Date format from query result
	ATHENAQUERYRESULTS=`aws athena get-query-results --query-execution-id $EXECUTIONID | jq -r '.ResultSet.Rows[0].Data[0].VarCharValue' | awk '{print $2}'`
	echo Date format in CUR file is $ATHENAQUERYRESULTS.

	# Define the Date format string for physical configuration file
	if [ "$ATHENAQUERYRESULTS" = "bigint" ]; then
		DATEFORMAT="INTEGER"
	elif [ "$ATHENAQUERYRESULTS" = "timestamp" ]; then
		DATEFORMAT="DATETIME"
	else
		DATEFORMAT="STRING"
	fi
}

isEMR() {
	# Construct the Athena query string to check existence of column resource_tags_aws_elasticmapreduce_job_flow_id
	EMRTAGQUERYSTRING="SELECT resource_tags_aws_elasticmapreduce_job_flow_id FROM "\"$ATHENADB\".\"$ATHENATABLE\"" limit 1"

	# Get the Athena execution ID by running Athena query
	EMRTAGEXECUTIONID=`aws athena start-query-execution \
	--query-string "$EMRTAGQUERYSTRING" \
	--result-configuration "OutputLocation"="$OUTPUTBUCKET" | jq -r '.QueryExecutionId'`

	# Validate the query result every 2 seconds
	for emrtimer in {1..15}
	do
		EMRTAGEXECUTIONSTATUS=`aws athena get-query-execution --query-execution-id $EMRTAGEXECUTIONID | jq -r '.QueryExecution.Status.State'`
		
		# If qeury succeed, set the flag to has-emr-tag
		if [[ $EMRTAGEXECUTIONSTATUS == "SUCCEEDED" ]]; then
			EMR="has-emr-tag"
			break

		elif [[ $EMRTAGEXECUTIONSTATUS == "RUNNING" ]]; then
			if [[ $emrtimer == 15 ]]; then
				echo Checking EMR tag timeout, please check your network connectivity and try again.
				exit
			fi

		# If qeury failed, set the flag to no-emr-tag
		else			
			EMR="no-emr-tag"
			echo -e EMR cost allocation tag has not been enabled, visuals in EMR sheet will show "\033[33m \"No Data\" \033[0m".
			break
		fi

		sleep 2s
	done
}

isSP() {
	# Construct the Athena query string to check existence of column savings_plan_savings_plan_a_r_n
	SPQUERYSTRING="SELECT savings_plan_savings_plan_a_r_n FROM "\"$ATHENADB\".\"$ATHENATABLE\"" limit 1"

	# Get the Athena execution ID by running Athena query
	SPEXECUTIONID=`aws athena start-query-execution \
	--query-string "$SPQUERYSTRING" \
	--result-configuration "OutputLocation"="$OUTPUTBUCKET" | jq -r '.QueryExecutionId'`

	# Validate the query result every 2 seconds
	for sptimer in {1..15}
	do
		SPEXECUTIONSTATUS=`aws athena get-query-execution --query-execution-id $SPEXECUTIONID | jq -r '.QueryExecution.Status.State'`
		
		# If qeury succeed, set the flag to has-sp-column
		if [[ $SPEXECUTIONSTATUS == "SUCCEEDED" ]]; then
			SP="has-sp-column"
			break

		elif [[ $SPEXECUTIONSTATUS == "RUNNING" ]]; then
			if [[ $sptimer == 15 ]]; then
				echo Checking SP columns timeout, please check your network connectivity and try again.
				exit
			fi

		# If qeury failed, set the flag to no-sp-column
		else	
			SP="no-sp-column"			
			break
		fi

		sleep 2s
	done
}

isEDP() {
	# Construct the Athena query string to check existence of column "line_item_net_unblended_cost", _net_ represent it's a EDP column
	EDPQUERYSTRING="SELECT line_item_net_unblended_cost FROM "\"$ATHENADB\".\"$ATHENATABLE\"" limit 1"

	# Get the Athena execution ID by running Athena query
	EDPEXECUTIONID=`aws athena start-query-execution \
	--query-string "$EDPQUERYSTRING" \
	--result-configuration "OutputLocation"="$OUTPUTBUCKET" | jq -r '.QueryExecutionId'`

	# Validate the query result every 2 seconds
	for edptimer in {1..15}
	do
		EDPEXECUTIONSTATUS=`aws athena get-query-execution --query-execution-id $EDPEXECUTIONID | jq -r '.QueryExecution.Status.State'`
		
		# If qeury succeed, set the flag to has-edp
		if [[ $EDPEXECUTIONSTATUS == "SUCCEEDED" ]]; then
			EDP="has-edp-column"
			break

		elif [[ $EDPEXECUTIONSTATUS == "RUNNING" ]]; then

			if [[ $edptimer == 15 ]]; then
				echo Checking EDP timeout, please check your network connectivity and try again.
				exit
			fi

			echo Checking EDP item from CUR table...

		# If qeury failed, set the flag to no-edp-column
		else
			EDP="no-edp-column"

			break
		fi

		sleep 2s
	done
}


updateConfigurationFile() {
	### Note: Column name in physical configuration file cannot be same with calculated column defined in logical configuration file
	
	### Update EMR tag part
	# If EMR cost allocation disabled, delete resource_tags_aws_elasticmapreduce_job_flow_id part in physical config file
	if [[ $EMR == "no-emr-tag" ]];then
		cat physical-table-map.json | jq 'del(.string.RelationalTable.InputColumns[] | select(.Name == "resource_tags_aws_elasticmapreduce_job_flow_id"))' >> tmpjson && mv tmpjson physical-table-map.json
	# If EMR cost allocation enabled, delete resource_tags_aws_elasticmapreduce_job_flow_id part in logical config file
	else
		cat logical-table-map.json | jq 'del(.string.DataTransforms[] | select(.CreateColumnsOperation.Columns[0].ColumnName == "resource_tags_aws_elasticmapreduce_job_flow_id"))' >> tmpjson && mv tmpjson logical-table-map.json
	fi

	### Update Saving Plan comumn part
	# If do not contain SP items, delete SP columns in physical config file and replate sp item with a valid item[any one is ok] in logical configuration file
	if [[ $SP == "no-sp-column" ]];then
		cat physical-table-map.json | jq 'del(.string.RelationalTable.InputColumns[] | select(.Name == "savings_plan_region"))' >> tmpjson && mv tmpjson physical-table-map.json
		cat physical-table-map.json | jq 'del(.string.RelationalTable.InputColumns[] | select(.Name == "savings_plan_net_savings_plan_effective_cost"))' >> tmpjson && mv tmpjson physical-table-map.json
		cat physical-table-map.json | jq 'del(.string.RelationalTable.InputColumns[] | select(.Name == "savings_plan_net_amortized_upfront_commitment_for_billing_period"))' >> tmpjson && mv tmpjson physical-table-map.json
		cat physical-table-map.json | jq 'del(.string.RelationalTable.InputColumns[] | select(.Name == "savings_plan_net_recurring_commitment_for_billing_period"))' >> tmpjson && mv tmpjson physical-table-map.json
		sed -i "s/{savings_plan_net_savings_plan_effective_cost}/{reservation_net_effective_cost}/g" logical-table-map.json

	# If contain SP items, delete SP columns in logical config file
	else
		cat logical-table-map.json | jq 'del(.string.DataTransforms[] | select(.CreateColumnsOperation.Columns[0].ColumnName == "savings_plan_net_savings_plan_effective_cost"))' >> tmpjson && mv tmpjson logical-table-map.json

	fi

	### update Athena configurations and EDP/SP related columns
	### Note: update this at last, in case column name changed before deletion in previous steps
	
	sed -i "s#DATEFORMATHOLDER#$DATEFORMAT#" physical-table-map.json
	sed -i "s#ATHENADBHOLDER#$ATHENADB#" physical-table-map.json
	sed -i "s#ATHENATABLEHOLDER#$ATHENATABLE#" physical-table-map.json

	if [[ $EDP == "no-edp-column" ]];then
		sed -i "s/_net_/_/g" logical-table-map.json
		sed -i "s/_net_/_/g" physical-table-map.json
	fi

	if [[ $SP == "no-sp-column" ]]; then
		sed -i "s#+{savings_plan_net_savings_plan_effective_cost}##" logical-table-map.json
		sed -i "s#+{savings_plan_savings_plan_effective_cost}##" logical-table-map.json
	fi
	
}

getQSUserARN(){
	# Because identity region are different for users, and no api to get identity region, we need to consider all supported regions
	IDENTITYREGIONLIST=($REGIONCUR $CURRENTREGION us-east-1 us-east-2 us-west-2 eu-central-1 eu-west-1 eu-west-2 ap-southeast-1 ap-northeast-1 ap-southeast-2 ap-northeast-2 ap-south-1)

	# Check the identity region in supported regions one by one
	for identityregioniterator in "${IDENTITYREGIONLIST[@]}";do
		# Get user list from checking region
		QSUSERLIST=`aws quicksight list-users --aws-account-id $AccountID --namespace default --region $identityregioniterator`
		
		# Given Null cannot be caught on Cloud 9, we get the length of query result
		QSUSERLISTLENGTH=${#QSUSERLIST}

		# If query result length lower than 1, match failed, need to check next region
		if [ "$QSUSERLISTLENGTH" -lt 1 ]; then
			echo ""
			echo Searching correct identity region ...

		# If query result lenght greater than 0, match succesfully
		else
			echo ""
			echo Identity region matched !

			# Get the user numbers in user list
			QSUSERNUMBER=`echo $QSUSERLIST | jq -r '.UserList|length'`
			break
		fi

	done

	# If the user list only has one result, set QSUSERARN as this user arn 
	if [ $QSUSERNUMBER -lt 2 ]; then
		QSUSERARN=`echo $QSUSERLIST | jq -r '.UserList[0].Arn'`

	# If the user list has multiple results, print it for selection
	else
		echo ""
		echo "*****************************************************************************"
		echo $QSUSERLIST | jq -r '.UserList[].Arn'
		echo "*****************************************************************************"
		echo ""
		read -p "Please select correct quicksight user arn from above output, then enter:" QSUSERARN
			
	fi
}

updateDataSourcePermissions(){
	# Get the data source update result
	UPDATERESULT=`aws quicksight update-data-source-permissions \
	--aws-account-id $AccountID \
	--data-source-id $DATASOURCEID \
	--grant-permissions Principal=$QSUSERARN,Actions="quicksight:DescribeDataSource","quicksight:DescribeDataSourcePermissions","quicksight:PassDataSource","quicksight:UpdateDataSource","quicksight:DeleteDataSource","quicksight:UpdateDataSourcePermissions"`

	# If update result is null, usually caused by incorrect QuickSight user arn, run getQSUserARN to get correct one and updateDataSourcePermissions again
	if [ "$UPDATERESULT" = "" ]; then
		echo ""
		echo "Update datasource permissions failed, retrying ..."
		echo ""

		getQSUserARN
		updateDataSourcePermissions

		return
	else
		echo "Update datasource permissions successfully."
	fi
}

### Main function start here

aws configure set aws_access_key_id $ACCESSKEY
aws configure set aws_secret_access_key $SECRETKEY
aws configure set default.region $REGIONCUR

# Necessary parameters from cloudformation
# REGIONCUR
# QUERYMODE
# ATHENADB
# ATHENATABLE
# OUTPUTBUCKET
# DELETEEXISTINGRESOURCE

# Set the environment variable AWS_DEFAULT_REGION value to destionation region
export AWS_DEFAULT_REGION=$REGIONCUR
# Set default output format
export AWS_DEFAULT_OUTPUT="json"

# Get the running profile
stsresult=`aws sts get-caller-identity`
echo "sts get-caller-identity result:" >> /home/ec2-user/qscurlog.txt
echo $stsresult >> /home/ec2-user/qscurlog.txt
echo "" >> /home/ec2-user/qscurlog.txt

# Get the Account ID by running profile
AccountID=`echo $stsresult | jq -r '.Account'`

# Get the user arn by running profile
IAMARN=`echo $stsresult | jq -r '.Arn'`

# Define the QuickSight template, this is maintained by AWS GCR Enterprise Support team
QSTEMARN="arn:aws:quicksight:us-east-1:673437017715:template/CUR-MasterTemplate-Pub"

# Check if user choosed to delete existing resources created by this tool
if [ "$DELETEEXISTINGRESOURCE" = "yes" -o "$DELETEONLY" = "yes" ]; then
	# Define keyword of resources ID created by this tool
	DATASOURCEID="cur-datasource-id-"$REGIONCUR
	DATASETID="cur-dataset-id-"$REGIONCUR
	DASHBOARDID="cur-dashboard-id-"$REGIONCUR

	# Delete resources created for CUR generated from global and China region
	dashboardnum=0
	datasetnum=0
	datasourcenum=0

	DASHBOARDLIST=`aws quicksight list-dashboards --aws-account-id $AccountID --region $REGIONCUR | jq -r '.DashboardSummaryList[].DashboardId'`
	DASHBOARDARRAY=($DASHBOARDLIST)

	for dashboarditerator in "${DASHBOARDARRAY[@]}";do 
		if [[ $dashboarditerator =~ $DASHBOARDID ]];then 
			aws quicksight delete-dashboard --aws-account-id $AccountID --dashboard-id $dashboarditerator --region $REGIONCUR
			let dashboardnum=$dashboardnum+1
		fi
	done

	DATASETLIST=`aws quicksight list-data-sets --aws-account-id $AccountID --region $REGIONCUR | jq -r '.DataSetSummaries[].DataSetId'`
	DATASETARRAY=($DATASETLIST)

	for datasetiterator in "${DATASETARRAY[@]}";do 
		if [[ $datasetiterator =~ $DATASETID ]];then 
			aws quicksight delete-data-set --aws-account-id $AccountID --data-set-id $datasetiterator --region $REGIONCUR
			let datasetnum=$datasetnum+1
		fi
	done

	DATASOURCELIST=`aws quicksight list-data-sources --aws-account-id $AccountID --region $REGIONCUR | jq -r '.DataSources[].DataSourceId'`
	DATASOURCEARRAY=($DATASOURCELIST)

	for datasourceiterator in "${DATASOURCEARRAY[@]}";do 
		if [[ $datasourceiterator =~ $DATASOURCEID ]];then 
			aws quicksight delete-data-source --aws-account-id $AccountID --data-source-id $datasourceiterator --region $REGIONCUR
			let datasourcenum=$datasourcenum+1
		fi
	done

	echo ""
	echo Deletion Summary:
	echo $dashboardnum dashboard\(s\) deleted.
	echo $datasetnum dataset\(s\) deleted.
	echo $datasourcenum datasource\(s\) deleted.
		
fi

# If user choose to delete only, exit script after resource deletion
if [[ $DELETEONLY == "yes" ]]; then
	exit
fi

# Based on the CUR source region, bjs or global, we will define different name for datasource/dataset/dashboard
getCURDataSourceRegion

# We need to get the raw date format in CUR, then define ETL configuration in locagical config file in necessary
getCURDateFormat

# Generate physical configuration file
PHYSICALTEMFILE="do-not-delete-physical-tem"
cp DataSetTems/$PHYSICALTEMFILE physical-table-map.json

# Generate logical configuration file
LOGICALTEMFILE="do-not-delete-logical-tem"
cp DataSetTems/$LOGICALTEMFILE logical-table-map.json

### Run isEMR,isEDP and isSP to check CUR talbe columns, then use theses vlues to update physical&logical configuration files, prepared for dataset creation
# Check if EMR cost allocation tag enabled on this account
isEMR

# Check if EDP enabled
isEDP

# Check if Saving Plan columns exist
isSP

# Add blank line before resource creation
echo ""

# Update physical&logical config file based on isEMR/isEDP/isSP results
updateConfigurationFile

### Assemble the QuickSight user arn by running profile
# Not working on Isengard cli: IAMNAME=`aws iam get-user | jq -r '.User.UserName'`; So add TMPARN to suppot on Isengard account in v0.33
TMPARN=`echo $stsresult | jq -r '.Arn'`

# Truncate current IAM user name
IAMNAME=${TMPARN#*/}

# Assemble the QuickSight user arn
QSUSERARN=arn:aws:quicksight:us-east-1:$AccountID:user/default/$IAMNAME

# Create QuickSight DataSource  
DATASOURCEID=$CURDATASOURCEREGIONSTRING"cur-datasource-id-"$REGIONCUR
DATASOURCENAME=$CURDATASOURCEREGIONSTRING"cur-datasource-"$REGIONCUR

aws quicksight create-data-source \
--aws-account-id $AccountID \
--data-source-id $DATASOURCEID \
--name $DATASOURCENAME \
--type ATHENA \
--data-source-parameters AthenaParameters={WorkGroup=primary}

# Tracking the creation status of data source every 2 seconds
for datasourcetimer in {1..15}
do
	DATASOURCECREATIONSTATUS=`aws quicksight describe-data-source --aws-account-id $AccountID --data-source-id $DATASOURCEID | jq -r '.DataSource.Status'`

	if [[ $DATASOURCECREATIONSTATUS == "CREATION_SUCCESSFUL" ]]; then
		echo Datasource has been created successfully!		
		break

	elif [[ $DATASOURCECREATIONSTATUS == "CREATION_IN_PROGRESS" ]]; then
		echo Datasource creation in progress...

		if [[ $datasourcetimer == 15 ]]; then
			echo Datasource creation timeout, please check your network connectivity and try again.
			exit
		fi
	else
		echo ""
		echo Datasource creation failed. Please run following command to check details:
		echo aws quicksight describe-data-source --aws-account-id $AccountID --data-source-id $DATASOURCEID --region $REGIONCUR
		echo ""
		exit
	fi

	sleep 2s
done

# Authorize permissons for DataSource created just now
updateDataSourcePermissions

# Get the DataSource ARN created in previous step, prepared for DataSet creation
DATASOURCEARN=`aws quicksight describe-data-source --aws-account-id $AccountID --data-source-id $DATASOURCEID | jq -r '.DataSource.Arn'`

# Update Data-Srouce ARN to physical configuration file, prepared for DataSet creation
sed -i "s#DATASOURCEARNHOLDER#$DATASOURCEARN#" physical-table-map.json


# Create quicksight DataSet using updated configuration file
DATASETID=$CURDATASOURCEREGIONSTRING"cur-dataset-id-"$REGIONCUR
DATASETNAME=$CURDATASOURCEREGIONSTRING"cur-dataset-"$REGIONCUR

aws quicksight create-data-set \
--aws-account-id $AccountID \
--data-set-id $DATASETID \
--name $DATASETNAME \
--physical-table-map file://physical-table-map.json \
--logical-table-map file://logical-table-map.json \
--import-mode $QUERYMODE

# Note: No need to track dataset creation progress
# Authorize permissons for Created DataSet
aws quicksight update-data-set-permissions \
--aws-account-id $AccountID \
--data-set-id $DATASETID \
--grant-permissions Principal=$QSUSERARN,Actions="quicksight:DescribeDataSet","quicksight:DescribeDataSetPermissions","quicksight:PassDataSet","quicksight:DescribeIngestion","quicksight:ListIngestions","quicksight:UpdateDataSet","quicksight:DeleteDataSet","quicksight:CreateIngestion","quicksight:CancelIngestion","quicksight:UpdateDataSetPermissions"

### Create DashBoard based on previous DataSet and existing template
# Assemble the DataSet arn
DATASETARN=arn:aws:quicksight:$REGIONCUR:$AccountID:dataset/$DATASETID

# Assemble the source-entity json string for QuickSight Dashboard
DASHSOURCENT='{"SourceTemplate":{"DataSetReferences":[{"DataSetPlaceholder":"customer_all","DataSetArn":"'$DATASETARN'"}],"Arn":"'$QSTEMARN'"}}'

# Define the dashoard ID and Name
DASHBOARDID=$CURDATASOURCEREGIONSTRING"cur-dashboard-id-"$REGIONCUR
DASHBOARDNAME=$CURDATASOURCEREGIONSTRING"cur-dashboard-"$REGIONCUR

aws quicksight create-dashboard \
--aws-account-id $AccountID \
--dashboard-id $DASHBOARDID \
--name $DASHBOARDNAME \
--source-entity $DASHSOURCENT

# Tracking the creation status of dashboard every 2 seconds
for dashboardtimer in {1..15}
do
	DASHBOARDCREATIONSTATUS=`aws quicksight describe-dashboard --aws-account-id $AccountID --dashboard-id $DASHBOARDID | jq -r '.Dashboard.Version.Status'`

	if [[ $DASHBOARDCREATIONSTATUS == "CREATION_SUCCESSFUL" ]]; then
		echo Dashboard has been created successfully!
		break

	elif [[ $DASHBOARDCREATIONSTATUS == "CREATION_IN_PROGRESS" ]]; then
		
		if [[ $dashboardtimer == 15 ]]; then
			echo Dashboard creation timeout, please check your network connectivity and try again.
			exit
		fi

		echo Dashboard creation in progress...
	else
		echo ""
		echo Dashboard creation failed. Please run following command to check details:
		echo aws quicksight describe-dashboard --aws-account-id $AccountID --dashboard-id $DASHBOARDID --region $REGIONCUR
		echo ""
		exit
	fi

	sleep 2s
done

# Authorize permissions for created DashBoard
aws quicksight update-dashboard-permissions \
--aws-account-id $AccountID \
--dashboard-id $DASHBOARDID \
--grant-permissions Principal=$QSUSERARN,Actions="quicksight:DescribeDashboard","quicksight:ListDashboardVersions","quicksight:UpdateDashboardPermissions","quicksight:QueryDashboard","quicksight:UpdateDashboard","quicksight:DeleteDashboard","quicksight:DescribeDashboardPermissions","quicksight:UpdateDashboardPublishedVersion" \
--region $REGIONCUR

echo ""
echo -e "\033[1;32mCUR virsualization solution has been deployed in $REGIONCUR successfully! You can analyze your cost from QuickSight dashboard now.\033[0m"
echo ""
