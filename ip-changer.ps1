Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope Process -Force

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

function Test-Admin {
    $currentPrincipal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
    $currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Get-NetworkAdapters {
    Get-NetAdapter | Select-Object -Property Name
}

function ConvertTo-PrefixLength {
    param(
        [string]$SubnetMask
    )
    $binMask = ($SubnetMask -split "\." | ForEach-Object { [convert]::ToString([int]$_, 2).PadLeft(8, '0') }) -join ''
    return ($binMask.ToCharArray() | Where-Object { $_ -eq '1' }).Count
}


function Enable-DHCP {
    param(
        $Name
    )
    Set-NetIPInterface -InterfaceAlias $Name -Dhcp Enabled
}

function Set-NetworkAdapterWithNetsh {
    param(
        $Name,
        $IPAddress,
        $SubnetMask,
        $Gateway
    )

    $interfaceName = (Get-NetAdapter | Where-Object { $_.InterfaceAlias -eq $Name }).Name

    $setIpAddressCmd = "interface ip set address `"$interfaceName`" static $IPAddress $SubnetMask $Gateway"
    Invoke-Expression "netsh $setIpAddressCmd"

    if ($LASTEXITCODE -ne 0) {
        Write-Host "Failed to set static IP address. Error code: $LASTEXITCODE"
    }
}


function Save-Configuration {
    param(
        $FilePath,
        $Data
    )
    $Data | ConvertTo-Json | Set-Content -Path $FilePath
}

function Load-Configuration {
    param(
        $FilePath
    )
    if (Test-Path $FilePath) {
        Get-Content -Path $FilePath | ConvertFrom-Json
    } else {
        @()
    }
}

function Show-LabelInputForm {
    param(
        [ScriptBlock]$OnSubmit
    )

    $labelForm = New-Object System.Windows.Forms.Form
    $labelForm.StartPosition = 'CenterScreen'
    $labelForm.Size = New-Object System.Drawing.Size(300,150)
    $labelForm.Text = 'Enter Configuration Label'
    $labelForm.FormBorderStyle = 'FixedDialog'
    $labelForm.MaximizeBox = $false
    $labelForm.MinimizeBox = $false

    $labelTextBox = New-Object System.Windows.Forms.TextBox
    $labelTextBox.Location = New-Object System.Drawing.Point(10,10)
    $labelTextBox.Size = New-Object System.Drawing.Size(260,20)
    $labelForm.Controls.Add($labelTextBox)

    $submitButton = New-Object System.Windows.Forms.Button
    $submitButton.Location = New-Object System.Drawing.Point(10,40)
    $submitButton.Size = New-Object System.Drawing.Size(100,23)
    $submitButton.Text = 'Submit'
    $submitButton.Add_Click({
        & $OnSubmit $labelTextBox.Text
        $labelForm.Close()
    })
    $labelForm.Controls.Add($submitButton)

    $cancelButton = New-Object System.Windows.Forms.Button
    $cancelButton.Location = New-Object System.Drawing.Point(120,40)
    $cancelButton.Size = New-Object System.Drawing.Size(100,23)
    $cancelButton.Text = 'Cancel'
    $cancelButton.Add_Click({ $labelForm.Close() })
    $labelForm.Controls.Add($cancelButton)

    $labelForm.ShowDialog() | Out-Null
}

function Validate-IPAddress {
    param($IPAddress)
    if ($IPAddress -match "^\d{1,3}(\.\d{1,3}){3}$") {
        $valid = $true
        $IPAddress.Split('.') | ForEach-Object {
            if ($_ -gt 255 -or $_ -lt 0) {
                $valid = $false
            }
        }
        return $valid
    } else {
        return $false
    }
}

if ((Test-Admin) -eq $false)  {
    if ($elevated) {
        # tried to elevate, did not work, aborting
    } else {
        Start-Process powershell.exe -Verb RunAs -ArgumentList ('-noprofile -noexit -file "{0}" -elevated' -f ($myinvocation.MyCommand.Definition))
    }
    exit
}

$form = New-Object System.Windows.Forms.Form
$form.Text = 'Network Configuration Tool'
$form.Size = New-Object System.Drawing.Size(400,500)
$form.FormBorderStyle = 'FixedDialog'
$form.MaximizeBox = $false
$form.MinimizeBox = $false

$adapterLabel = New-Object System.Windows.Forms.Label
$adapterLabel.Location = New-Object System.Drawing.Point(10,20)
$adapterLabel.Size = New-Object System.Drawing.Size(280,20)
$adapterLabel.Text = 'Network Adapter:'
$form.Controls.Add($adapterLabel)

$adapterComboBox = New-Object System.Windows.Forms.ComboBox
$adapterComboBox.Location = New-Object System.Drawing.Point(10,40)
$adapterComboBox.Size = New-Object System.Drawing.Size(280,20)
$form.Controls.Add($adapterComboBox)

$ipLabel = New-Object System.Windows.Forms.Label
$ipLabel.Location = New-Object System.Drawing.Point(10,70)
$ipLabel.Size = New-Object System.Drawing.Size(280,20)
$ipLabel.Text = 'IP Address:'
$form.Controls.Add($ipLabel)

$ipTextBox = New-Object System.Windows.Forms.TextBox
$ipTextBox.Location = New-Object System.Drawing.Point(10,90)
$ipTextBox.Size = New-Object System.Drawing.Size(280,20)
$form.Controls.Add($ipTextBox)

$subnetLabel = New-Object System.Windows.Forms.Label
$subnetLabel.Location = New-Object System.Drawing.Point(10,120)
$subnetLabel.Size = New-Object System.Drawing.Size(280,20)
$subnetLabel.Text = 'Subnet Mask:'
$form.Controls.Add($subnetLabel)

$subnetTextBox = New-Object System.Windows.Forms.TextBox
$subnetTextBox.Location = New-Object System.Drawing.Point(10,140)
$subnetTextBox.Size = New-Object System.Drawing.Size(280,20)
$form.Controls.Add($subnetTextBox)

$gatewayLabel = New-Object System.Windows.Forms.Label
$gatewayLabel.Location = New-Object System.Drawing.Point(10,170)
$gatewayLabel.Size = New-Object System.Drawing.Size(280,20)
$gatewayLabel.Text = 'Gateway:'
$form.Controls.Add($gatewayLabel)

$gatewayTextBox = New-Object System.Windows.Forms.TextBox
$gatewayTextBox.Location = New-Object System.Drawing.Point(10,190)
$gatewayTextBox.Size = New-Object System.Drawing.Size(280,20)
$form.Controls.Add($gatewayTextBox)

$submitButton = New-Object System.Windows.Forms.Button
$submitButton.Location = New-Object System.Drawing.Point(10,220)
$submitButton.Size = New-Object System.Drawing.Size(75,23)
$submitButton.Text = 'Submit'
$form.Controls.Add($submitButton)

$submitButton.Add_Click({
    $ipValid = Validate-IPAddress -IPAddress $ipTextBox.Text
    $subnetValid = Validate-IPAddress -IPAddress $subnetTextBox.Text
    $gatewayValid = Validate-IPAddress -IPAddress $gatewayTextBox.Text

    if ($ipValid -and $subnetValid -and $gatewayValid) {
        Set-NetworkAdapterWithNetsh -Name $adapterComboBox.Text -IPAddress $ipTextBox.Text -SubnetMask $subnetTextBox.Text -Gateway $gatewayTextBox.Text
    } else {
        [System.Windows.Forms.MessageBox]::Show("Invalid IP, Subnet, or Gateway format. Please enter valid IPv4 addresses.", "Validation Error")
    }
})

$dhcpButton = New-Object System.Windows.Forms.Button
$dhcpButton.Location = New-Object System.Drawing.Point(95,220)
$dhcpButton.Size = New-Object System.Drawing.Size(75,23)
$dhcpButton.Text = 'DHCP'
$form.Controls.Add($dhcpButton)

$dhcpButton.Add_Click({
    Enable-DHCP -Name $adapterComboBox.Text
})

$saveButton = New-Object System.Windows.Forms.Button
$saveButton.Location = New-Object System.Drawing.Point(180,220)
$saveButton.Size = New-Object System.Drawing.Size(75,23)
$saveButton.Text = 'Save'
$form.Controls.Add($saveButton)

$saveButton.Add_Click({
    Show-LabelInputForm -OnSubmit {
        param($configLabel)
        
        $configData = @{
            'IPAddress' = $ipTextBox.Text
            'SubnetMask' = $subnetTextBox.Text
            'Gateway' = $gatewayTextBox.Text
            'AdapterName' = $adapterComboBox.Text
        }

        $existingConfigs = @(Load-Configuration -FilePath "$PSScriptRoot\network_config.json")

        $index = -1
        for ($i = 0; $i -lt $existingConfigs.Count; $i++) {
            if ($existingConfigs[$i].Label -eq $configLabel) {
                $index = $i
                break
            }
        }

        if ($index -ne -1) {
            $existingConfigs[$index] = @{ 'Label' = $configLabel; 'Data' = $configData }
        } else {
            $existingConfigs += @{ 'Label' = $configLabel; 'Data' = $configData }
        }

        Save-Configuration -FilePath "$PSScriptRoot\network_config.json" -Data $existingConfigs

        $configListBox.Items.Clear()
        foreach ($config in $existingConfigs) {
            if ($null -ne $config.Label) {
                $configListBox.Items.Add($config.Label)
            }
        }
    }
})

$configListLabel = New-Object System.Windows.Forms.Label
$configListLabel.Location = New-Object System.Drawing.Point(10,250)
$configListLabel.Size = New-Object System.Drawing.Size(280,20)
$configListLabel.Text = 'Saved Configurations:'
$form.Controls.Add($configListLabel)

$configListBox = New-Object System.Windows.Forms.ListBox
$configListBox.Location = New-Object System.Drawing.Point(10,270)
$configListBox.Size = New-Object System.Drawing.Size(360,150)
$form.Controls.Add($configListBox)

$configListBox.Items.Clear()
foreach ($config in $existingConfigs) {
    if ($null -ne $config.Label) {
        $configListBox.Items.Add($config.Label)
    }
}

$adapters = Get-NetworkAdapters
foreach ($adapter in $adapters) {
    $adapterComboBox.Items.Add($adapter.Name)
}

$savedConfigs = Load-Configuration -FilePath "$PSScriptRoot\network_config.json"
$configListBox.Items.Clear()
foreach ($config in $savedConfigs) {
    if ($null -ne $config.Label) {
        $configListBox.Items.Add($config.Label)
    }
}

$configListBox.Add_Click({
    $selectedLabel = $configListBox.SelectedItem
    $selectedConfig = $savedConfigs | Where-Object { $_.Label -eq $selectedLabel } | Select-Object -ExpandProperty Data

    $ipTextBox.Text = $selectedConfig.IPAddress
    $subnetTextBox.Text = $selectedConfig.SubnetMask
    $gatewayTextBox.Text = $selectedConfig.Gateway
    $adapterComboBox.Text = $selectedConfig.AdapterName
})

$form.ShowDialog()