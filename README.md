{% highlight posh %}
Function Global:Trace-Route {
    [CmdletBinding()]
    param(
        $ComputerName,
        $Hops = 30
    )
    Function Get-RoutingInterface {
        Param(
            [System.Net.Sockets.Socket] $socket,
            [System.Net.IPEndPoint] $remoteEndPoint
        )
        [System.Net.SocketAddress]$address = $remoteEndPoint.Serialize()

        $remoteAddrBytes = New-Object byte[] $address.Size
        for ($i = 0; $i -lt $address.Size; $i++) {
            $remoteAddrBytes[$i] = $address[$i]
        }

        $outBytes = New-Object byte[] $remoteAddrBytes.Length
        [Void]$socket.IOControl( [System.Net.Sockets.IOControlCode]::RoutingInterfaceQuery, $remoteAddrBytes, $outBytes)
        for ($i = 0; $i -lt $address.Size; $i++) {
            $address[$i] = $outBytes[$i]
        }

        $ep = $remoteEndPoint.Create($address)

        $AllInterfaces = [System.Net.NetworkInformation.NetworkInterface]::GetAllNetworkInterfaces() | ? NetworkInterfaceType -eq "Ethernet"
        $AllInterfaces | % { 
            If ( $ep.Address -eq $_.GetIPProperties().UnicastAddresses.Address) { Return $_.Name, $ep.Address }
        }
    }

    $Ping = New-Object System.Net.NetworkInformation.Ping
    $PingOptions = New-Object System.Net.NetworkInformation.PingOptions
    $PingOptions.Ttl = 1
    $DataBuffer = New-Object byte[] 10
    $ReturnTrace = New-Object System.Collections.ArrayList

    Try {
        $HostEntry =[System.Net.Dns]::GetHostEntry($ComputerName)
        $Hostname = $HostEntry.HostName
        $TargetIPAddress = $HostEntry.AddressList.IPAddressToString
        $PingSucceeded = Test-Ping $Hostname
    } Catch {
       Throw "Unable to resolve target system name $ComputerName."
    }

    Write-Verbose -Message ([string]::Format("Tracing route to {0} [{1}] over a maximum of {2} hops:",$Hostname, $TargetIPAddress, $Hops))
    [console]::TreatControlCAsInput = $true
    $remoteIp = [IPAddress]::Parse($TargetIPAddress)
    $remoteEndPoint = New-Object System.Net.IPEndPoint($remoteIp, 0)
    $socket = New-Object System.Net.Sockets.Socket([System.Net.Sockets.AddressFamily]::InterNetwork, [System.Net.Sockets.SocketType]::Dgram, [System.Net.Sockets.ProtocolType]::Udp)
    $InterfaceName, $SourceAdress = Get-RoutingInterface -socket $socket -remoteEndPoint $remoteEndPoint

    Do {
        try {
            $CurrentHop = [int] $PingOptions.Ttl
            write-progress -CurrentOperation "TTL = $CurrentHop" -Status "ICMP Echo Request (Max TTL = $Hops)" -Activity "TraceRoute" -PercentComplete -1 -SecondsRemaining -1
            $PingReplyDetails = $Ping.Send($TargetIPAddress, 4000, $DataBuffer, $PingOptions)
            If ($PingReplyDetails.Address -eq $null) {
                Write-Verbose  -Message ([string]::Format(" {0}    {1}    {2}",$CurrentHop, '*', $PingReplyDetails.Status.ToString()))
                [Void]$ReturnTrace.Add($PingReplyDetails.Status.ToString())
            } Else {
                Write-Verbose  -Message ([string]::Format(" {0}    {1}    {2}",$CurrentHop, $PingReplyDetails.RoundtripTime, $PingReplyDetails.Address.IPAddressToString))
                [Void]$ReturnTrace.Add($PingReplyDetails.Address.IPAddressToString)
            }
        } catch {
            Write-Debug "Exception thrown in PING send"
            Write-Verbose "..."
            [Void]$ReturnTrace.Add("...")
        }
        If ([console]::KeyAvailable) {
            $key = [system.console]::readkey($true)
            If (($key.modifiers -band [consolemodifiers]"control") -and ($key.key -eq "C")) {
                $breaking = $true
                Write-Verbose -Message "Control-C"
                break
            }
        }

        $PingOptions.Ttl++
    } While (($PingReplyDetails.Status -ne 'Success') -and ($PingOptions.Ttl -le $Hops))
    [console]::TreatControlCAsInput = $false
    Write-Verbose -Message "Trace Completed."
    ##If the last entry in the trace does not equal the target, then the trace did not successfully complete
    If ($ReturnTrace[-1] -ne $TargetIPAddress) {
        $OutputString = "Trace route to destination " + $TargetIPAddress + " did not complete. Trace terminated :: " + $ReturnTrace[-1]
        Write-Warning $OutputString
    }
    $Return = [PsCustomObject] @{ ComputerName = $Hostname ; RemoteAddress = $TargetIPAddress ; InterfaceAlias = $InterfaceName ; SourceAddress = $SourceAdress ; PingSucceeded = $PingSucceeded ; TraceRoute = $ReturnTrace }
    $Return.PsTypeNames.Insert(0,'emmToolSet.TraceRoute')
    return $Return
}
{% endhighlight %}











## Welcome to GitHub Pages

You can use the [editor on GitHub](https://github.com/amenatis/amenatis.github.io/edit/master/README.md) to maintain and preview the content for your website in Markdown files.

Whenever you commit to this repository, GitHub Pages will run [Jekyll](https://jekyllrb.com/) to rebuild the pages in your site, from the content in your Markdown files.

### Markdown

Markdown is a lightweight and easy-to-use syntax for styling your writing. It includes conventions for

```markdown
Syntax highlighted code block

# Header 1
## Header 2
### Header 3

- Bulleted
- List

1. Numbered
2. List

**Bold** and _Italic_ and `Code` text

[Link](url) and ![Image](src)
```

For more details see [GitHub Flavored Markdown](https://guides.github.com/features/mastering-markdown/).

### Jekyll Themes

Your Pages site will use the layout and styles from the Jekyll theme you have selected in your [repository settings](https://github.com/amenatis/amenatis.github.io/settings). The name of this theme is saved in the Jekyll `_config.yml` configuration file.

### Support or Contact

Having trouble with Pages? Check out our [documentation](https://help.github.com/categories/github-pages-basics/) or [contact support](https://github.com/contact) and we’ll help you sort it out.
