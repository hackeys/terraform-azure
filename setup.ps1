# Variables that can be defined, or left blank
[String]$azure_client_name=""     	# Application name
[Securestring]$azure_client_secret  # Application password
[String]$azure_group_name=""
[String]$azure_storage_name=""
[String]$azure_subscription_id="" 	# Derived from the account after login
[String]$azure_tenant_id=""       	# Derived from the account after login
[String]$location="West Europe"
[String]$azure_object_id=""


function Requirements() {
	$found=0
	$azureversion = (Get-Module -ListAvailable -Name Azure -Refresh)
	If ($azureversion.Version.Major -gt 0) {
		$found=$found + 1
		Write-Output "Found Azure PowerShell version: $($azureversion.Version.Major).$($azureversion.Version.Minor)"
	}
	Else {
		Write-Output "Azure PowerShell is missing. Please download and install Azure PowerShell from"
		Write-Output "http://aka.ms/webpi-azps"		
	}
	return $found
}

function AskSubscription() {
	$azuresubscription = Add-AzureRmAccount
	$script:azure_subscription_id = $azuresubscription.Context.Subscription.SubscriptionId
	$script:azure_tenant_id = $azuresubscription.Context.Subscription.TenantId		
}

Function RandomComplexPassword () {
	param ( [int]$Length = 8 )
 	#Usage: RandomComplexPassword 12
 	$Assembly = Add-Type -AssemblyName System.Web
 	$RandomComplexPassword = [System.Web.Security.Membership]::GeneratePassword($Length,2)
 	return $RandomComplexPassword
}

function AskName() {
	Write-Output ""
	Write-Output "Choose a name for your client."
	Write-Output "This is mandatory - do not leave blank."
	Write-Output "ALPHANUMERIC ONLY. Ex: mytfdeployment."
	Write-Output -n "> "
	$script:meta_name = Read-Host
}

function AskSecret() {
	Write-Output ""
	Write-Output "Enter a secret for your application. We recommend generating one with"
	Write-Output "openssl rand -base64 24. If you leave this blank we will attempt to"
	Write-Output "generate one for you using .Net Security Framework. THIS WILL BE SHOWN IN PLAINTEXT."
	Write-Output "Ex: myterraformsecret8734"
	Write-Output -n "> "
	$script:azure_client_secret = Read-Host
	if ($script:azure_client_secret -eq "") {
		$script:azure_client_secret = RandomComplexPassword(43)
	}	
	Write-Output "Client_secret: $script:azure_client_secret"
	$script:password = ConvertTo-SecureString $script:azure_client_secret -AsPlainText -Force
}

function CreateServicePrinciple() {
	Write-Output "==> Creating service principal"
	$app = New-AzureRmADApplication -DisplayName $meta_name -HomePage "https://$script:meta_name" -IdentifierUris "https://$script:meta_name" -Password $script:password
 	New-AzureRmADServicePrincipal -ApplicationId $app.ApplicationId	
	#sleep 30 seconds to allow resource creation to converge
	Write-Output "Allow for 30 seconds to create the service principal"
	Start-Sleep -s 30
 	New-AzureRmRoleAssignment -RoleDefinitionName Owner -ServicePrincipalName $app.ApplicationId.Guid
	$script:azure_client_id = $app.ApplicationId
	$script:azure_object_id = $app.ObjectId
	if ($error.Count > 0)
	{
		Write-Output "Error creating service principal: $azure_client_id"
		exit
	}
}

function ShowConfigs() {
	Write-Output ""
	Write-Output "Use the following configuration for your Terraform scripts:"
	Write-Output ""
	Write-Output "{"
	Write-Output "      'client_id': $azure_client_id,"
	Write-Output "      'client_secret': $azure_client_secret,"
	Write-Output "      'subscription_id': $azure_subscription_id,"
	Write-Output "      'tenant_id': $azure_tenant_id"
	Write-Output "}"
	Write-Output ""
	Write-Output "Use the following Environmetal variable direct in PowerShell Terminal"
	Write-Output ""
	Write-Output "`$env:ARM_CLIENT_ID=`"$azure_client_id`""
	Write-Output "`$env:ARM_CLIENT_SECRET=`"$azure_client_secret`""
	Write-Output "`$env:ARM_TENANT_ID=`"$azure_tenant_id`""
	Write-Output "`$env:ARM_SUBSCRIPTION_ID=`"$azure_subscription_id`""
	Write-Output ""
}

$reqs = Requirements	
	if($reqs -gt 0)
	{
		AskSubscription
		AskName
		AskSecret
		CreateServicePrinciple
		ShowConfigs
	}
