function Get-PkiCaIssuedCertificate {
	<#
	.SYNOPSIS
		Lists issued certificates.
	
	.DESCRIPTION
		Lists issued certificates.
	
	.PARAMETER ComputerName
		The computername of the CA (automatically detects the CA name)
		Specifying this will cause the command to use PowerShell remoting.

	.PARAMETER Credential
		The credentials to use when connecting to the server.
		Only used in combination with -ComputerName.
		
	.PARAMETER FQCAName
		The fully qualified name of the CA.
		Specifying this allows remote access to the target CA.
		'<Computername>\<CA Name>'

	.PARAMETER CommonName
		Filter by common name.

	.PARAMETER RequestID
		Search for a certificate by its specific request ID.

	.PARAMETER Requester
		Search for certificates by who requested them.

	.PARAMETER TemplateName
		Search for certificates by the template they were made from.
	
	.PARAMETER Properties
		The properties to retrieve.
		These are the headers as shown in the CA mmc console on an English languaged device.
		The result objects will have the same properties, but without the whitespace.

	.PARAMETER Server
		The active directory server to contact using LDAP.
		Used to resolve the templates used.
	
	.EXAMPLE
		PS C:\> Get-PkiCaIssuedCertificate
	
		Returns all issued certificates from the current computer (assumes localhost is a CA)

    .EXAMPLE
        PS C:\> Get-PkiCaIssuedCertificate -FQCAName "ca.contoso.com\MS-CA-01"

		Returns all issued certificates from the CA "ca.contoso.com\MS-CA-01"
		Requires the local computer to have the CA management tools installed

	.EXAMPLE
		PS C:\> Get-PkiCaIssuedCertificate -Computername ca.contoso.com

		Returns all issued certificate from ca.contoso.com.
		Requires PS remoting access to the target computerh osting the CA service.
#>
	[Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSAvoidUsingEmptyCatchBlock", "")]
	[CmdletBinding()]
	param (
		[PSFComputer[]]
		$ComputerName,

		[PSCredential]
		$Credential,
		
		[string]
		$FQCAName,

		[string]
		$CommonName,

		[int]
		$RequestID,

		[string]
		$Requester,

		[PsfArgumentCompleter('PkiExtension.TemplateName')]
		[string]
		$TemplateName,
		
		[String[]]
		$Properties = (
			'Issued Common Name',
			'Certificate Expiration Date',
			'Certificate Effective Date',
			'Certificate Template',
			'Issued Request ID',
			'Certificate Hash',
			'Request Disposition Message',
			'Requester Name',
			'Binary Certificate'
		),

		[string]
		$Server
	)
	begin {
		$tmplParam = $PSBoundParameters | ConvertTo-PSFHashtable -Include Server, Credential
		$templates = Get-PkiTemplate @tmplParam
		
		$data = @{
			FQCAName     = $FQCAName
			Properties   = $Properties
			Templates    = $templates
			CommonName   = $CommonName
			RequestID    = $RequestID
			Requester    = $Requester
			TemplateName = $TemplateName
		}

		$parameters = @{
			ArgumentList = $data
		}
		if ($ComputerName) {
			$parameters["HideComputerName"] = $true
			$parameters["ComputerName"] = $ComputerName
			if ($Credential) {
				$parameters['Credential'] = $Credential
			}
		}
	}
	process {
		Invoke-PSFCommand @parameters -ScriptBlock {
			param (
				$Data
			)

			# Copy variables over
			foreach ($pair in $Data.GetEnumerator()) {
				Set-Variable -Name $pair.Key -Value $pair.Value
			}

			$ErrorActionPreference = 'Stop'
			trap {
				Write-Warning "Error retrieving Certificate information: $_"
				throw $_
			}
			
			#region Preparation CA Connect
			try { $caView = New-Object -ComObject CertificateAuthority.View }
			catch { throw "Unable to create Certificate Authority View. $env:COMPUTERNAME does not have ADSC Installed" }
			
			if ($FQCAName) {
				$null = $CaView.OpenConnection($FQCAName)
			}
			else {
				$caName = (Get-ItemProperty -Path 'HKLM:\System\CurrentControlSet\Services\CertSvc\Configuration' -Name Active).Active
				$null = $caView.OpenConnection("$($env:COMPUTERNAME)\$($caName)")
			}
			$CaView.SetResultColumnCount($Properties.Count)
			
			foreach ($item in $Properties) {
				$index = $caView.GetColumnIndex($false, $item)
				$caView.SetResultColumn($index)
			}
			
			# https://learn.microsoft.com/en-us/windows/win32/api/certview/nf-certview-icertview-setrestriction
			$CVR_SEEK_EQ = 1
			# $CVR_SEEL_LE = 2
			# $CVR_SEEK_LT = 4
			# $CVR_SEEK_GE = 8
			# $CVR_SEEK_GT = 16

			$CVR_SORT_NONE = 0
			
			# 20 - issued certificates
			$caView.SetRestriction($caView.GetColumnIndex($false, 'Request Disposition'), $CVR_SEEK_EQ, $CVR_SORT_NONE, 20)
			if ($CommonName) { $caView.SetRestriction($caView.GetColumnIndex($false, 'Issued Common Name'), $CVR_SEEK_EQ, $CVR_SORT_NONE, $CommonName) }
			if ($RequestID) { $caView.SetRestriction($caView.GetColumnIndex($false, 'Issued Request ID'), $CVR_SEEK_EQ, $CVR_SORT_NONE, $RequestID) }
			if ($Requester) { $caView.SetRestriction($caView.GetColumnIndex($false, 'Requester Name'), $CVR_SEEK_EQ, $CVR_SORT_NONE, $Requester) }
			if ($TemplateName) {
				$templateID = ($Templates | Where-Object DisplayName -EQ $TemplateName).'msPKI-Cert-Template-OID'
				if (-not $templateID) { $templateID = $TemplateName }
				$caView.SetRestriction($caView.GetColumnIndex($false, 'Certificate Template'), $CVR_SEEK_EQ, $CVR_SORT_NONE, $templateID)
			}

			
			$CV_OUT_BASE64HEADER = 0
			$CV_OUT_BASE64 = 1
			$RowObj = $caView.OpenView()
			#endregion Preparation CA Connect
			
			#region Process Certificates
			while ($RowObj.Next() -ne -1) {
				#region Process Properties
				$Cert = @{
					PSTypeName = "PkiExtension.IssuedCertificate"
				}
				$ColObj = $RowObj.EnumCertViewColumn()
				$null = $ColObj.Next()
				do {
					$displayName = $ColObj.GetDisplayName()
					# format Binary Certificate in a savable format.
					if ($displayName -eq 'Binary Certificate') {
						$Cert[$displayName.Replace(" ", "")] = $ColObj.GetValue($CV_OUT_BASE64HEADER)
						$Cert['Certificate'] = [System.Security.Cryptography.X509Certificates.X509Certificate2]::new(([System.Text.Encoding]::UTF8.GetBytes($Cert[$displayName.Replace(" ", "")])))
					}
					else { $Cert[$displayName.Replace(" ", "")] = $ColObj.GetValue($CV_OUT_BASE64) }
				}
				until ($ColObj.Next() -eq -1)
				Clear-Variable -Name ColObj
				#endregion Process Properties
				
				#region Process Template Name
				$Cert['TemplateDisplayName'] = $null
				if ($Cert.CertificateTemplate) {
					try {
						$Cert['TemplateDisplayName'] = ($Templates | Where-Object msPKI-Cert-Template-OID -EQ $Cert.CertificateTemplate).DisplayName
						if (-not $Cert['TemplateDisplayName']) {
							$Cert['TemplateDisplayName'] = ($Templates | Where-Object Name -EQ $Cert.CertificateTemplate).DisplayName
						}
						if (-not $Cert['TemplateDisplayName']) { $Cert['TemplateDisplayName'] = $Cert.CertificateTemplate }
						if ($Cert['Certificate']) { Add-Member -InputObject $Cert['Certificate'] -MemberType NoteProperty -Name TemplateDisplayName -Value $Cert['TemplateDisplayName'] }
					}
					catch { }
				}
				#endregion Process Template Name
				
				[pscustomobject]$Cert | Add-Member -MemberType ScriptMethod -Name ToString -Value { $this.IssuedCommonName } -Force -PassThru
			}
			#endregion Process Certificates
		} | Select-PSFObject -KeepInputObject -TypeName 'PkiExtension.IssuedCertificate'
	}
}