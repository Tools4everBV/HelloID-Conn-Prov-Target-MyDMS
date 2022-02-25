#####################################################
# HelloID-Conn-Prov-Target-MyDMS-Create
#
# Version: 1.0.0
#####################################################
# Initialize default value's
$config = $configuration | ConvertFrom-Json
$p = $person | ConvertFrom-Json
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

# Begin
try {
    # Initalize Authorization Headers
    $pair = "$($config.UserName):$($config.Password)"
    $encodedCreds = [System.Convert]::ToBase64String([System.Text.Encoding]::ASCII.GetBytes($pair))
    $basicAuthValue = "Basic $encodedCreds"
    $Headers = @{
        Authorization = $basicAuthValue
    }

    # Verify if a user must be created or correlated
    try {
        $connection = @{
            Method      = 'GET'
            Uri         = $config.BaseUrl + "/user?employeeNr=$($account._employeeNr)"
            Body        = $null
            ContentType = 'application/json'
            Headers     = $Headers
            Verbose     = $false
        }
        $AccountResponse = Invoke-RestMethod @connection
    } catch {
        if ($($_.Exception.GetType().FullName -eq 'Microsoft.PowerShell.Commands.HttpResponseException') -or
            $($_.Exception.GetType().FullName -eq 'System.Net.WebException')) {
            $errorObj = Resolve-HTTPError -ErrorObject $_
            $errorMessage = "$($errorObj.ErrorMessage)"
        } else {
            $errorMessage = "$($_.Exception.Message)"
        }
    }
    if ($errorMessage -match 'User account not found') {
        $action = 'Create'
    } else {
        $action = 'CorrelateAndUpdate'
    }

    if ($dryRun -eq $true) {
        $auditLogs.Add([PSCustomObject]@{
                Message = "$action MyDMS account for: [$($p.DisplayName)], will be executed during enforcement"
            })
    }

    # Process
    if (-not($dryRun -eq $true)) {
        switch ($action) {
            'Create' {
                Write-Verbose "Creating MyDMS account for: [$($p.DisplayName)]"
                $connection['Method'] = 'Post'
                $connection['body'] = ($account | ConvertTo-Json)
                $connection['Uri'] = $config.BaseUrl + '/user'
                $AccountResponse = Invoke-RestMethod @connection
                break
            }
            'CorrelateAndUpdate' {
                Write-Verbose "Correlating and update MyDMS account for: [$($p.DisplayName)]"
                $account | Add-Member @{
                    _id = $AccountResponse._id
                }
                $connection['Method'] = 'Post'
                $connection['body'] = ($account | ConvertTo-Json)
                $connection['Uri'] = $config.BaseUrl + '/user'
                $AccountResponse = Invoke-RestMethod @connection
                break
            }
        }
        $accountReference = $AccountResponse._id
        $success = $true
        $auditLogs.Add([PSCustomObject]@{
                Message = "$action account for: [$($p.DisplayName)] was successful. accountReference is: [$accountReference]"
                IsError = $false
            })
    }
} catch {
    $success = $false
    $ex = $PSItem
    if ($($ex.Exception.GetType().FullName -eq 'Microsoft.PowerShell.Commands.HttpResponseException') -or
        $($ex.Exception.GetType().FullName -eq 'System.Net.WebException')) {
        $errorObj = Resolve-HTTPError -ErrorObject $ex
        $errorMessage = "Could not $action MyDMS account for: [$($p.DisplayName)]. Error: $($errorObj.ErrorMessage)"
    } else {
        $errorMessage = "Could not $action MyDMS account for: [$($p.DisplayName)]. Error: $($ex.Exception.Message)"
    }
    Write-Verbose $errorMessage
    $auditLogs.Add([PSCustomObject]@{
            Message = $errorMessage
            IsError = $true
        })
} finally {
    $result = [PSCustomObject]@{
        Success          = $success
        AccountReference = $accountReference
        Auditlogs        = $auditLogs
        Account          = $account
    }
    Write-Output $result | ConvertTo-Json -Depth 10
}
