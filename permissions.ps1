#####################################################
# HelloID-Conn-Prov-Target-MyDMS-Permissions
#
# Version: 1.0.0
#####################################################
# Initialize default value's
$config = $configuration | ConvertFrom-Json

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
    # Initalize Authorization Headers
    $pair = "$($config.UserName):$($config.Password)"
    $encodedCreds = [System.Convert]::ToBase64String([System.Text.Encoding]::ASCII.GetBytes($pair))
    $basicAuthValue = "Basic $encodedCreds"
    $Headers = @{
        Authorization = $basicAuthValue
    }

    $connection = @{
        Method  = 'GET'
        Uri     = $config.BaseUrl + '/group/list'
        Headers = $Headers
    }
    $permissions = Invoke-RestMethod @connection -Verbose:$false

    #ToDo Incorrect response retrieved from the webservice ! Fix /test the code after the webservice result is solved.
    $persmissionsCorrected = $permissions.substring($permissions.indexof('[')) | ConvertFrom-Json
    $permissions = $persmissionsCorrected

    $permissions | ForEach-Object {
        $_ | Add-Member @{
            DisplayName    = $_._name
            Identification = @{
                Id          = $_._id
                DisplayName = $_._name
            }
        }
    }

    Write-Output $permissions | ConvertTo-Json -Depth 10
} catch {
    $ex = $PSItem
    if ($($ex.Exception.GetType().FullName -eq 'Microsoft.PowerShell.Commands.HttpResponseException') -or
        $($ex.Exception.GetType().FullName -eq 'System.Net.WebException')) {
        $errorObj = Resolve-HTTPError -ErrorObject $ex
        $errorMessage = "Could not retrieve MyDMS permissions. Error: $($errorObj.ErrorMessage)"
    } else {
        $errorMessage = "Could not retrieve MyDMS permissions. Error: $($ex.Exception.Message)"
    }
    Write-Verbose $errorMessage
}
