![Polly](https://github.com/TetrationAnalytics/polymath/raw/images/polly.jpg "Polly")

# Polymath

Reconstitute Linux and macOS machine configurations via scripts

## Linux - Run scripts via

```
# polly <cookbook_name>
bash <(curl -fsSL https://raw.githubusercontent.com/TetrationAnalytics/polymath/master/polly)
```

Can also remove or install Chef without running a script:

```
# Remove Chef
bash <(curl -fsSL https://raw.githubusercontent.com/TetrationAnalytics/polymath/master/polly) nukechef

# Install Chef
bash <(curl -fsSL https://raw.githubusercontent.com/TetrationAnalytics/polymath/master/polly) chef
```

## Windows - Run scripts via
```
invoke-restmethod https://raw.githubusercontent.com/TetrationAnalytics/polymath/master/polly.ps1 | iex
polly chef
polly nukechef
```
### PowerShell proxy settings

In order to make these commands work on a system behind a proxy server `PowerShell` needs to be prepared (just setting the `-Proxy` parameter for the `Invoke-RestMethod' won't be enough). 

#### PS 4.x/5.x

To set up the proxy config with `NetShell` on `PowerShell` v5.x and older run:
```
netsh winhttp set proxy "http://proxy.esl.cisco.com:80" bypass-list="*.cisco.com,*.tetrationanalytics.com,*.h4.ai,*.ocean.af,*.tet.wtf,<local>"
```

It may also be necessary to enable certain protocols first, i.e. TLS1.2:
```
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
```
Ideally add this to the PowerShell profile file, the path is configured as `$PROFILE` by default.

To verify that the proxy is configured, run:
```
netsh winhttp show proxy
```

`NetShell` does also allow to copy the proxy config from the system's internet settings, if configured already:
```
netsh winhttp import proxy source=ie
```
**Note:** *If a user has the proxy settings populated in IE, they will overrule any settings made with `netsh`!*

#### PS 6.x/7.x

In the newer versions as well as `PowerShell Core` the following configures a proxy shell-wide:
```
[System.Net.Http.HttpClient]::DefaultProxy = New-Object System.Net.WebProxy('http://proxy.esl.cisco.com:80')
```

These newer versions also allow the use of respective environment variables, just like in Linux:
 - `HTTP_PROXY` for HTTP requests
 - `HTTPS_PROXY` for HTTPS requests
 - `ALL_PROXY` for both HTTP and HTTPS
 - `NO_PROXY` may contain a comma-separated list of hostnames excluded from proxying

### Set proxy in IE Connection Settings

To configure the IE proxy options from the command line set them in the registry:
```
reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\Internet Settings" /v ProxyEnable /t REG_DWORD /D 1 /f
reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\Internet Settings" /v ProxyServer /t REG_SZ /d proxy.esl.cisco.com:80 /f
reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\Internet Settings" /v ProxyOverride /t REG_SZ /d "*.cisco.com,*.tetrationanalytics.com,*.tet.wtf,*.h4.ai,*.ocean.af,<local>" /f
```
**Note:** *`<local>` must be at the end of the string here, otherwise the entire list will be ignored by PowerShell if these settings overrule any others configured there!*

### Verifying proxy settings for specific URLs

To check if a request will be proxied, run the following, setting `$uri` to a valid URL:
```
$uri = "http://<URL>"
(new-object System.Net.WebClient).Proxy.GetProxy($uri).AbsoluteUri
```

#### Examples
This is an internal address and therefore requests to it will connect directly, bypassing the proxy.
```
PS C:\Users\Administrator> (new-object System.Net.WebClient).Proxy.GetProxy("https://tools.ocean.af").AbsoluteUri
https://tools.ocean.af/
```

The second example shows an external address, so the command returns the URL of the proxy instead.
```
PS C:\Users\Administrator> (new-object System.Net.WebClient).Proxy.GetProxy("https://www.google.com").AbsoluteUri
http://proxy.esl.cisco.com/
```

### Chef installation/removal

```
# Remove Chef
invoke-restmethod https://raw.githubusercontent.com/TetrationAnalytics/polymath/master/polly.ps1 | iex
polly nukechef

# Install Chef
invoke-restmethod https://raw.githubusercontent.com/TetrationAnalytics/polymath/master/polly.ps1 | iex
polly chef
```
