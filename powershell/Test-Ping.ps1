Function Global:Test-Ping {
    [CmdletBinding()]
    [OutputType([System.Boolean])]
    param(
        [Parameter(ValueFromPipeline=$true)]
        [String]$ComputerName,
        [Int]$w=1000,
        [int]$n = 4,
        [Switch]$t,
        [int]$l = 32,
        [Switch]$f,
        [int]$i = 64
    )

    If (-not $PSBoundParameters.ContainsKey('n')) {
        If ($VerbosePreference -ne 'Continue') { $n = 1 }
    }

    Try {
        $HostEntry =[System.Net.Dns]::GetHostEntry($ComputerName)
        $Hostname = $HostEntry.HostName
        $IpAddress = $HostEntry.AddressList.IPAddressToString
    } Catch {
       Throw "Ping request could not find host $ComputerName. Please check the name and try again."
    }

    Try {
        $ArPingResponses = New-Object System.Collections.ArrayList
        $pingOptions = New-Object System.Net.NetworkInformation.PingOptions
        $pingOptions.DontFragment = $f
        $pingOptions.Ttl = $i
        $buffer = New-Object byte[] $l
        $pingResults = New-Object System.Text.StringBuilder
        Write-Verbose -Message ([string]::Format("Pinging {0} [{1}] with {2} bytes of data:",$Hostname, $ipAddress, $l))
        [console]::TreatControlCAsInput = $true
        for ( $i=0 ; $i -lt $n ; $i++ ) {
            If ($t) { $i-- }  #For infinite loop
            $sentPings++
            Try {
                $Reply = (New-Object System.Net.NetworkInformation.Ping).Send($IpAddress, $w, $buffer, $pingOptions)
                If ( $Reply.Status -eq [System.Net.NetworkInformation.IPStatus]::Success ) {
                    Write-Verbose -Message ("Reply from {0}: bytes={1} time={2}ms TTL={3}" -f $ipAddress, $($reply.Buffer.Length), $($Reply.RoundtripTime), $($Reply.Options.Ttl)  )
                    If ($minPingResponse -eq 0) {
                        $minPingResponse = $Reply.RoundtripTime
                        $maxPingResponse = $minPingResponse
                    } elseif ($Reply.RoundtripTime -le $minPingResponse) {
                        $minPingResponse = $Reply.RoundtripTime
                    } elseif ($Reply.RoundtripTime -gt $maxPingResponse) {
                        $maxPingResponse = $Reply.RoundtripTime
                    }
                    [Void]$ArPingResponses.Add($Reply.RoundtripTime)
                    If ($VerbosePreference -ne 'Continue') { $true }
                    $receivedPings++
                    
                } Elseif ($Reply.Status -eq [System.Net.NetworkInformation.IPStatus]::TimedOut) {
                    Write-Verbose -Message "Request timed out."
                    If ($VerbosePreference -ne 'Continue') { $false }
                    $lostPings++
                }
                Else { Write-error -Message "Request error: $($Reply.Status)."}
                If ($i -ne $n -1) { Sleep 1 }
                    
            } Catch {
                $false
            }
            If ([console]::KeyAvailable) {
                $key = [system.console]::readkey($true)
                If (($key.modifiers -band [consolemodifiers]"control") -and ($key.key -eq "C")) {
                    $breaking = $true
                    Write-Verbose -Message "Control-C"
                    break
                }
            }

        }
    } Finally {
        [console]::TreatControlCAsInput = $false
        
        $PurcentLoss = [int]$lostPings/[int]$sentPings*100
        [Void]$pingResults.AppendLine([string]::Format("Ping statistics for {0}:", $ipAddress))
        [Void]$pingResults.AppendLine([string]::Format("`tPackets: Sent = {0}, Received = {1}, Lost = {2} ({3}% loss),", [int]$sentPings, [int]$receivedPings, [int]$lostPings, [int]$PurcentLoss))
        If ([int]$receivedPings -ge 1) {
            $ArPingResponses.ForEach({$sum += $_})
            $AvPingResponse = $sum/$ArPingResponses.Count
            [Void]$pingResults.AppendLine("Approximate round trip times in milli-seconds:")
            [Void]$pingResults.AppendLine([string]::Format("`tMinimum = {0}ms, Maximum = {1}ms, Average = {1}ms", [int]$minPingResponse, [int]$maxPingResponse, [long]$AvPingResponse  ))
        }
        Write-Verbose $pingResults
    }
}
