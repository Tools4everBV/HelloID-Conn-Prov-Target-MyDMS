#####################################################
# HelloID-Conn-Prov-Target-MyDMS-Update
#
# Version: 1.0.0
#####################################################
# Initialize default value's
$config = $configuration | ConvertFrom-Json
$p = $person | ConvertFrom-Json
$aRef = $AccountReference | ConvertFrom-Json
$pp = $previousPerson | Convertfrom-Json
$success = $false
$auditLogs = [System.Collections.Generic.List[PSCustomObject]]::new()

# Account mapping
$account = [PSCustomObject]@{
    _login           = $p.Contact.Business.Email
    _upn             = $p.Contact.Business.Email
    _firstName       = $p.Name.NickName
    _lastName        = $p.Name.FamilyName
    _fullName        = $p.DisplayName
    _email           = $p.Contact.Business.Email
    _employeeNr      = $p.ExternalId
    _startEmployment = $p.PrimaryContract.StartDate
    _endEmployment   = $p.PrimaryContract.EndDate
    _function        = $p.PrimaryContract.Title.ExternalId
    _phone           = $p.Contact.Business.Phone.Fixed
    _mobile          = $p.Contact.Business.Phone.Mobile
}

$previousAccount = [PSCustomObject]@{
    _login           = $pp.Contact.Business.Email
    _upn             = $pp.Contact.Business.Email
    _firstName       = $pp.Name.NickName
    _lastName        = $pp.Name.FamilyName
    _fullName        = $pp.DisplayName
    _email           = $pp.Contact.Business.Email
    _employeeNr      = $pp.ExternalId
    _startEmployment = $pp.PrimaryContract.StartDate
    _endEmployment   = $pp.PrimaryContract.EndDate
    _function        = $pp.PrimaryContract.Title.ExternalId
    _phone           = $pp.Contact.Business.Phone.Fixed
    _mobile          = $pp.Contact.Business.Phone.Mobile
}
# Enable TLS1.2
[System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor [System.Net.SecurityProtocolType]::Tls12

# Set debug logging
switch ($($config.IsDebug)) {
    $true { $VerbosePreference = 'Continue' }
    $false { $VerbosePreference = 'SilentlyContinue' }
}

#region functions
function Resolve-HTTPError {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory,
            ValueFromPipeline
        )]
        [object]$ErrorObject
    )
    process {
        $httpErrorObj = [PSCustomObject]@{
            FullyQualifiedErrorId = $ErrorObject.FullyQualifiedErrorId
            MyCommand             = $ErrorObject.InvocationInfo.MyCommand
            RequestUri            = $ErrorObject.TargetObject.RequestUri
            ScriptStackTrace      = $ErrorObject.ScriptStackTrace
            ErrorMessage          = ''
        }
        if ($ErrorObject.Exception.GetType().FullName -eq 'Microsoft.PowerShell.Commands.HttpResponseException') {
            $httpErrorObj.ErrorMessage = $ErrorObject.ErrorDetails.Message
        } elseif ($ErrorObject.Exception.GetType().FullName -eq 'System.Net.WebException') {
            $httpErrorObj.ErrorMessage = [System.IO.StreamReader]::new($ErrorObject.Exception.Response.GetResponseStream()).ReadToEnd()
        }
        Write-Output $httpErrorObj
    }
}
#endregion

try {
    #Verify if the properties in the account object are modified
    $propertiesChanged = (Compare-Object @($previousAccount.PSObject.Properties) @($account.PSObject.Properties) -PassThru)
    if ($null -eq $propertiesChanged) {
        $auditLogs.Add([PSCustomObject]@{
                Message = "Update account for: [$($p.DisplayName)] was successful.(No changes found)"
                IsError = $false
            })
        $success = $true
        continue
    }
    $body = @{
        _id = $aRef
    }
    foreach ($property in ($propertiesChanged)) {
        $body["$($property.name)"] = $account.$($property.name)
    }

    # Initalize Authorization Headers
    $pair = "$($config.UserName):$($config.Password)"
    $encodedCreds = [System.Convert]::ToBase64String([System.Text.Encoding]::ASCII.GetBytes($pair))
    $basicAuthValue = "Basic $encodedCreds"
    $Headers = @{
        Authorization = $basicAuthValue
    }

    # Add an auditMessage showing what will happen during enforcement
    if ($dryRun -eq $true) {
        $auditLogs.Add([PSCustomObject]@{
                Message = "Update MyDMS account for: [$($p.DisplayName)], will be executed during enforcement"
            })
    }

    if (-not($dryRun -eq $true)) {
        Write-Verbose "Updating MyDMS account: [$aRef] for: [$($p.DisplayName)]"
        $connection = @{
            Method      = 'Post'
            Uri         = $config.BaseUrl + '/user'
            Body        = ($body  | ConvertTo-Json)
            ContentType = 'application/json'
            Headers     = $Headers
        }
        $AccountResponse = Invoke-RestMethod @connection -Verbose:$false
        $success = $true
        $auditLogs.Add([PSCustomObject]@{
                Message = "Update account for: [$($p.DisplayName)] was successful."
                IsError = $false
            })
    }
} catch {
    $success = $false
    $ex = $PSItem
    if ($($ex.Exception.GetType().FullName -eq 'Microsoft.PowerShell.Commands.HttpResponseException') -or
        $($ex.Exception.GetType().FullName -eq 'System.Net.WebException')) {
        $errorObj = Resolve-HTTPError -ErrorObject $ex
        $errorMessage = "Could not update MyDMS account for: [$($p.DisplayName)]. Error: $($errorObj.ErrorMessage)"
    } else {
        $errorMessage = "Could not update MyDMS account for: [$($p.DisplayName)]. Error: $($ex.Exception.Message)"
    }
    Write-Verbose $errorMessage
    $auditLogs.Add([PSCustomObject]@{
            Message = $errorMessage
            IsError = $true
        })
} finally {
    $result = [PSCustomObject]@{
        Success   = $success
        Account   = $account
        Auditlogs = $auditLogs
    }
    Write-Output $result | ConvertTo-Json -Depth 10
}
