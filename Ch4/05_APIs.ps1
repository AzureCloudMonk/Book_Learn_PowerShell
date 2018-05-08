#region Create the API
$polarisPath = [System.IO.Path]::GetTempFileName() -replace '\.tmp','\Polaris'
git clone https://github.com/powershell/polaris $polarisPath
Import-Module $polarisPath

$middleWare = @"
    `$PolarisPath = '$polarisPath\FileSvc'
    if (-not (Test-Path `$PolarisPath))
    {
        [void] (New-Item `$PolarisPath -ItemType Directory)
    }
    if (`$Request.BodyString -ne `$null)
    {
        `$Request.Body = `$Request.BodyString | ConvertFrom-Json
    }
"@

New-PolarisRouteMiddleware -Name JsonBodyParser -ScriptBlock ([scriptblock]::Create($middleWare))

# Create
New-PolarisPutRoute -Path "/files" -Scriptblock {
    if (-not $request.Body.Name -or -not $request.Body.Content)
    {
        $response.SetStatusCode(501)
        $response.Send("File name and file content may not be empty.")
        return    
    }

    [void] (New-Item -ItemType File -Path $PolarisPath -Name $request.Body.Name -Value $request.Body.Content)
}

# Read
New-PolarisGetRoute -Path "/files" -Scriptblock {

    $gciParameters = @{
        Path = $PolarisPath
        Filter = '*'
        ErrorAction = 'SilentlyContinue'
    }

    $gciParameters.Filter = if ($request.Query['Name'])
    {
        $request.Query['Name']
    }
    elseif ($request.Body.Name)
    {
        $request.Body.Name
    }

    $files = Get-ChildItem @gciParameters | Select-Object -Property @{Name = 'Name'; Expression = {$_.Name}},@{Name = 'Content'; Expression = $_ | Get-Content -Raw}

    $Response.Send(($files | ConvertTo-Json));
} -Force

# Update
New-PolarisPostRoute -Path "/files" -Scriptblock {
    if (-not $request.Body.Name -or -not $request.Body.Content)
    {
        $response.SetStatusCode(501)
        $response.Send("File name and file content may not be empty.")
        return    
    }

    [void] (Set-Item -ItemType File -Path $PolarisPath -Name $request.Body.Name -Value $request.Body.Content)
}

# Delete
New-PolarisDeleteRoute -Path "/files" -Scriptblock {
    $fileName = if ($request.Query['Name'])
    {
        $request.Query['Name']
    }
    elseif ($request.Body.Name)
    {
        $request.Body.Name
    }
    else
    {
        $response.SetStatusCode(501)
        $response.Send("File name may not be empty.")
        return    
    }
    
    Remove-Item -Path (Join-Path $PolarisPath -ChildPath $fileName)
}

Start-Polaris
#endregion

#region interaction


#endregion