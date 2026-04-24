function Get-PkiCaExpiringCertificate {
	<#
	.SYNOPSIS
		Retrieve a list of certificates about to expire.
	
	.DESCRIPTION
		Retrieve a list of certificates about to expire.
		Also includes information, whether the certificate has already been renewed or not.
	
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
	
	.PARAMETER DaysExpirationThreshold
		Only certificates that are still valid but will expire in the specified number of days will be returned.
		Defaults to: 14
	
	.PARAMETER Properties
		The properties to retrieve.
		These are the headers as shown in the CA mmc console on an English languaged device.
		The result objects will have the same properties, but without the whitespace.
	
	.PARAMETER TemplateName
		Only certificates of the specified template are being returned.

	.PARAMETER Server
		The active directory server to contact using LDAP.
		Used to resolve the templates used.

	.PARAMETER IgnoreTemplate
		Do not require matching templates on the renewal check.
		By default, a certificate is only considered renewed, if there is a certificiate that matches subject AND template that is still valid.
		Setting this parameter removes the template matching and should be used when migrating from one template to another.
	
	.EXAMPLE
		PS C:\> Get-PkiCaExpiringCertificate

		Get all issued certificates that will expire in the next 14 days.
	#>
	
	[CmdletBinding()]
	Param (
		[Parameter(ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true)]
		[PSFComputer[]]
		$ComputerName,

		[pscredential]
		$Credential,

		[string]
		$FQCAName,
		
		[int]
		$DaysExpirationThreshold = 14,

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
		
		[PsfArgumentCompleter('PkiExtension.TemplateName')]
		[string]
		$TemplateName,
	
		[string]
		$Server,

		[switch]
		$IgnoreTemplate
	)
	
	begin {
		$ThresholdDate = (Get-Date).AddDays($DaysExpirationThreshold)

		$required = @(
			'Certificate Expiration Date'
			'Issued Common Name'
		)

		#region Filter Conditions
		$isExpiring = {
			($_.CertificateExpirationDate -lt $ThresholdDate) -and
			(
				(-not $TemplateName) -or
				($_.CertificateTemplate -eq $TemplateName) -or
				($_.TemplateDisplayName -eq $TemplateName)
			)
		}
		$hasSuccessor = {
			$origin = $_
			$successor = $allCerts | Where-Object {
				($_ -ne $Origin) -and
				($_.CertificateExpirationDate -GE $ThresholdDate) -and
				($_.IssuedCommonName -eq $origin.IssuedCommonName) -and
				(
					(-not $TemplateName) -or
					($_.CertificateTemplate -eq $TemplateName) -or
					($_.TemplateDisplayName -eq $TemplateName)
				) -and
				(
					$IgnoreTemplate -or
					($_.CertificateTemplate -eq $origin.CertificateTemplate)
				)
			}
			$successor -as [bool]
		}
		$hasNoSuccessor = {
			$origin = $_
			$successor = $allCerts | Where-Object {
				($_ -ne $Origin) -and
				($_.CertificateExpirationDate -GE $ThresholdDate) -and
				($_.IssuedCommonName -eq $origin.IssuedCommonName) -and
				(
					(-not $TemplateName) -or
					($_.CertificateTemplate -eq $TemplateName) -or
					($_.TemplateDisplayName -eq $TemplateName)
				) -and
				(
					$IgnoreTemplate -or
					($_.CertificateTemplate -eq $origin.CertificateTemplate)
				)
			}
			-not $successor
		}
		$isSuccessor = {
			($_ -ne $currentCert) -and
			($_.CertificateExpirationDate -GE $ThresholdDate) -and
			($_.IssuedCommonName -eq $currentCert.IssuedCommonName) -and
			(
				(-not $TemplateName) -or
				($_.CertificateTemplate -eq $TemplateName) -or
				($_.TemplateDisplayName -eq $TemplateName)
			) -and
			(
				$IgnoreTemplate -or
				($_.CertificateTemplate -eq $currentCert.CertificateTemplate)
			)
		}
		#endregion Filter Conditions
	}
	process {
		$param = $PSBoundParameters | ConvertTo-PSFHashtable -ReferenceCommand Get-PkiCaIssuedCertificate
		if ($param.Properties) {
			foreach ($requiredProperty in $required) {
				if ($requiredProperty -in $param.Properties) { continue }
				$param.Properties = @($param.Properties) + $requiredProperty
			}
		}
		$allCerts = Get-PkiCaIssuedCertificate @param | Select-PSFObject -KeepInputObject -TypeName PkiExtension.ExpiringCertificate

		$expiredCerts = $allCerts | Where-Object $isExpiring

		$alreadyRenewedExpiredCerts = $expiredCerts | Where-Object $hasSuccessor
		$renewalPendingCerts = $expiredCerts | Where-Object $hasNoSuccessor
		
		$alreadyRenewedExpiredCerts | ForEach-Object {
			$currentCert = $_
			[PSFramework.Object.ObjectHost]::AddNoteProperty($currentCert, @{
				CertStatus = 'Renewed'
				RenewedBy = @($allCerts | Where-Object $isSuccessor | Sort-Object CertificateExpirationDate -Descending)[0]
			})
			$_
		}
		[PSFramework.Object.ObjectHost]::AddNotePropertyBulk($renewalPendingCerts, @{
			CertStatus = 'RenewalPending'
			RenewedBy = $null
		})
		$renewalPendingCerts
	}
}