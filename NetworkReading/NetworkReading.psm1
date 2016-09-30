Function Test-App
{
    <#
    .SYNOPSIS
        Test if any app exists

    .PARAMETER AppName
        If null or empty, using temp file

    #>
    [CmdletBinding(SupportsShouldProcess=$True)]
    param
    (
        [parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [string]$AppName = $null
    )
    process
    {
        Write-Host "Testing $AppName"

        Invoke-Expression "& $AppName --help"

        Write-Host "$AppName found"
        return $true

	Trap
	{
            Write-Host -message "$AppName not found"
            return $false
	}
   }
}

function Start-NetworkReading
{
    <#
    .SYNOPSIS
        Read network communication using ngrep

    .PARAMETER OutputFileName
        If null or empty, using temp file

    .PARAMETER DeviceNumber
        For windows only, see ngrep -L

    .OUTPUT
        Returns Output file

    .EXAMPLE
        "NetworkData.txt" | Start-NetworkReading
    #>

    [CmdletBinding(SupportsShouldProcess=$True)]
    param
    (
        [parameter(Mandatory = $false, ValueFromPipeline = $true)]
        [string]$OutputFileName = $null,

        [parameter(Mandatory = $false, ValueFromPipeline = $false)]
        $DeviceNumber = $null
    )
    process
    {
        if (-not (Test-App -AppName "ngrep"))
        {
            throw "ngrep not found, please install or add to path"
        }

        if (Test-NetworkReading)
        {
            throw "Network reading is already running"
        }

        Write-Host "Starting network reading"

        if ([String]::IsNullOrEmpty($OutputFileName))
        {
            $OutputFileName = [System.IO.Path]::GetTempFileName();
        }

        Write-Host ("Starting ngrep with output: " + $OutputFileName)


        if ($DeviceNumber -ne $null)
        {
            $DeviceNumberString = " -d $DeviceNumber "
        } else
        {
            $DeviceNumberString = ""
        }

        Start-Process -FilePath "ngrep" -ArgumentList ($DeviceNumberString + " -W single -qilw `"get`" tcp dst port 80 ")  -RedirectStandardOutput $OutputFileName -NoNewWindow

        Write-Host ("Waiting 5 secs for ngrep run test...")

        Start-Sleep -Seconds 5

        $runTestProcess = Get-Process | where { $_.ProcessName -like 'ngrep' }
        if ($runTestProcess -eq $null)
        {
            throw "ngrep failed to start"
        }

        $env:networkReader_outpufilename = $OutputFileName

        if (-not (Test-Path $OutputFileName))
        {
            # output file does not exist now
            "" | Out-File -FilePath $OutputFileName
        }

    	Get-Item $OutputFileName
    }
}

function Test-NetworkReading
{
    <#
    .SYNOPSIS
	Test network reading

    .OUTPUT
        $true/$false
    #>

    [CmdletBinding(SupportsShouldProcess=$True)]
    param
    (

    )
    process
    {
        Write-Host "Testing network reading"

        return (Get-Process | where { $_.ProcessName -like 'ngrep' }) -ne $null
    }
}

function Stop-NetworkReading
{
    <#
    .SYNOPSIS
	Stop network reading
        Kills all ngrep processes
    #>

    [CmdletBinding(SupportsShouldProcess=$True)]
    param
    (
    )
    process
    {
        Write-Host "Stopping network reading"

        if (Test-NetworkReading)
        {
            # Invoke-Expression "& killall ngrep"
            $processes = Get-Process | where { $_.ProcessName -like 'ngrep' }
            foreach ($process in $processes)
            {
                Write-Host ("Killing process ID " + $process.Id)
                $process.Kill()
            }
        } else
        {
            Write-Host "No running process found"
        }
    }
}

function Get-NetworkReadingOutputUrl
{
    <#
    .SYNOPSIS
        Get any url from network reading (ngrep) output

    .PARAMETER File
        Output File (Get-Item) provided by Start-NetworkReader (ngrep)
        if not present using environment variable $env:networkReader_outpufilename

    .EXAMPLE
        Get-NetworkReadingOutputUrl

    .EXAMPLE
        Get-Item /temp/streams.txt | Get-NetworkReadingOutputUrl  | Where-Object { $_.AbsoluteUri.Contains("m3u") }

     .OUTPUT
        Array of founded url
    #>

    [CmdletBinding(SupportsShouldProcess=$True)]
param
    (
        [parameter(Mandatory = $false, ValueFromPipeline = $true)]
        $File
    )
    process
    {
        if ($File -eq $null)
        {
            if (-not ([String]::IsNullOrEmpty($env:networkReader_outpufilename)))
            {
                $File = Get-Item $env:networkReader_outpufilename
            } else
            {
                throw "Output File not specified"
            }
        }

        if (-not ($File -is [System.IO.FileSystemInfo]))
        {
            throw "Not supported object"
        }

        Write-Host ("Getting url from: " + $File.FullName)

        $content = Get-Content -Path  $File.FullName

        $result = @()

        $i= 0
        foreach ($line in $content)
        {
            $urlStart = $line.IndexOf(" GET ")
            $urlFinish = $line.IndexOf(" HTTP")
            $hostStart = $line.IndexOf("Host: ")

            if (($urlStart -gt -1) -and ($urlfinish -gt -1) -and ($hostStart -gt -1))
            {
                $url = $line.Substring($urlStart+5,$urlFinish-$urlStart-5)

                $line = $line.Substring($hostStart)
                $hostFinish = $line.IndexOf("..")
                if ($hostFinish -gt -1)
                {
                    $urlHost = $line.Substring(6,$hostFinish-6)

                    $result += New-Object System.Uri("http://" + $urlHost + $url)
                }
            }

        }

        return $result
   }
}

function Select-NetworkReadingOutputUrl
{
    <#
    .SYNOPSIS
        Select streams provided by ngrep output

    .PARAMETER Url
        Array of url to select

    .PARAMETER Mask
        Mask of data file to receive
        Default mask is "m3u"

    .EXAMPLE
        Get-Item /temp/streams.txt | Get-NetworkReadingOutputUrl  | Where-Object { $_.AbsoluteUri.Contains("m3u") } | Select-NetworkReadingOutputUrl
    #>

    [CmdletBinding(SupportsShouldProcess=$True)]
    param
    (
        [parameter(Mandatory = $true, ValueFromPipeline = $true)]
        $Url,

        [parameter(Mandatory = $false, ValueFromPipeline = $false)]
        [string]$Mask = ""
    )
    begin
    {
        $allUrls = @()
    }
    process
    {
        if (([String]::IsNullOrEmpty($Mask)))
        {
            $allUrls += $Url
        } else
        {
            if ($url.AbsoluteUri.Contains($Mask))
            {
                $allUrls += $Url
            }
        }
    }
    end
    {
        if ($allUrls.Count -eq 0)
        {
            return $null;
        }

        Write-Host ("Selecting url")

	    $urlNumber = 1
        $alreadyProcessedUrl = @()
        $numberToUrl = @{}

        foreach ($u in $allUrls)
        {
            if (-not $alreadyProcessedUrl.Contains($u))
            {
                $alreadyProcessedUrl += $u
                $numberToUrl.Add($urlNumber,$u);

                Write-Host ($urlNumber.ToString() + ": " +$u)

                $urlNumber++;
            }
        }

        Write-Host ("Select url number to download: (1.." + ($urlNumber-1) + "):") -NoNewLine;

        $result = @()

        $numberAsString = Read-Host;

        $numbersAsString = $numberAsString.Split(",")
        foreach ($numAsString in $numbersAsString)
        {
            if ( $numAsString.Trim() -match "^[-]?[0-9.]+$")
            {
                $number = [System.Convert]::ToInt32($numAsString)
                if (($number -ge 1) -and ($number -le $urlNumber))
                {
                    Write-Host ("Selecting stream : " + $numberToUrl[$number])
                    $result += New-Object System.uri($numberToUrl[$number])
                }
            } else
            {
                Write-Host ("Invalid stream number "+$numAsString)
            }
        }

        return $result
    }
}

function Save-NetworkStream
{
    <#
    .SYNOPSIS
        Downloads stream by (ffmpeg)

    .PARAMETER Url
        Url of stream to download

    .PARAMETER OutoutFileName
        Name of received data file
        Default value is "stream"

    .PARAMETER OutputExtension
        Extension of received data file
        Default value is ".ts"

    .PARAMETER OutputDirectory
        Directory for receiving data
        Default value is "." (current directory)
    #>

    [CmdletBinding(SupportsShouldProcess=$True)]
    param
    (
        [parameter(Mandatory = $true, ValueFromPipeline = $true)]
        $Url,

        [parameter(Mandatory = $false, ValueFromPipeline = $false)]
        $OutputExtension  = ".ts",

        [parameter(Mandatory = $false, ValueFromPipeline = $false)]
        $OutputFileName = "stream",

        [parameter(Mandatory = $false, ValueFromPipeline = $false)]
        $OutputDirectory = "."
    )
    process
    {
        if (-not (Test-App -AppName "ffmpeg"))
        {
            throw "ffmpeg not found, please install or add to path"
        }

        if (-not ($OutputDirectory.EndsWith([System.IO.Path]::DirectorySeparatorChar)))
        {
            $OutputDirectory += [System.IO.Path]::DirectorySeparatorChar;
        }

        $urlNumber = 1
        while (Test-Path -Path ($OutputDirectory + $OutputFileName + $urlNumber.ToString().PadLeft(3,"0") + $OutputExtension))
        {
            $urlNumber++
        }

	$name = $OutputDirectory + $OutputFileName + $urlNumber.ToString().PadLeft(3,"0") + $OutputExtension

        Write-Host "Saving stream $Url by ffmpeg to $name"

        $cmd = "ffmpeg -i `"$Url`" -c copy `"$name`""

        Invoke-Expression "& $cmd"
    }
}

function Receive-NetworkStreamData
{
    <#
    .SYNOPSIS
        Downloads all streams (ffmpeg) provided by ngrep output

    .PARAMETER File
       Output File (Get-Item) provided by Start-NetworkReader (ngrep)
        if not present using environment variable $env:networkReader_outpufilename

    .PARAMETER Mask
        Mask of data file to receive
        Default mask is "m3u"

    .PARAMETER OutputFileName
        Extension of received data file
        Default value is "stream"

    .PARAMETER OutputExtension
        Extension of received data file
        Default value is ".ts"

    .PARAMETER OutputDirectory
        Directory for receiving data
        Default value is "." (current directory)

    .EXAMPLE
        Get-Item /temp/streams.txt | Receive-NetworkStreamData2
    #>

    [CmdletBinding(SupportsShouldProcess=$True)]
    param
    (
        [parameter(Mandatory = $false, ValueFromPipeline = $true)]
        $File,

        [parameter(Mandatory = $false, ValueFromPipeline = $false)]
        [string]$Mask = "m3u",

        [parameter(Mandatory = $false, ValueFromPipeline = $false)]
        $OutputExtension  = ".ts",

        [parameter(Mandatory = $false, ValueFromPipeline = $false)]
        $OutputFileName = "stream",

        [parameter(Mandatory = $false, ValueFromPipeline = $false)]
        $OutputDirectory = "."
    )
    process
    {

        Write-Host "Scannig ngrep output and receiving all streams"

	$urlNumber = 1
        $alreadyProcessedUrl = @()
        while ($true)
        {
            $urls = $File | Get-NetworkReadingOutputUrl | Where-Object { $_.AbsoluteUri.Contains($Mask) }
            foreach ($url in $urls)
            {
                if (-not ($alreadyProcessedUrl.Contains($url)))
                {
                    $url | Save-NetworkStream -OutputExtension $OutputExtension -OutputFileName $OutputFileName -OutputDirectory $OutputDirectory
                    
                    $alreadyProcessedUrl+= $url
                }
            }

            Write-Host "Waiting 5 seconds for next scan ..."
            Start-Sleep -Seconds 5
        }
    }
}

Export-ModuleMember Start-NetworkReading,Stop-NetworkReading,Test-NetworkReading,
                    Get-NetworkReadingOutputUrl,Select-NetworkReadingOutputUrl,
                    Save-NetworkStream,Receive-NetworkStreamData