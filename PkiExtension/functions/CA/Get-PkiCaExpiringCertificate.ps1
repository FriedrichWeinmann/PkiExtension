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
	
	.PARAMETER TemplateName
		Only certificates of the specified template are being returned.
	
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
		
		[PsfArgumentCompleter('PkiExtension.TemplateName')]
		[string]
		$TemplateName
	
	)
	
	begin {
		$ThresholdDate = (Get-Date).AddDays($DaysExpirationThreshold)
	}
	process {
		$param = $PSBoundParameters | ConvertTo-PSFHashtable -ReferenceCommand Get-PkiCaIssuedCertificate
		$allCerts = Get-PkiCaIssuedCertificate @param | Select-PSFObject -KeepInputObject -TypeName PkiExtension.ExpiringCertificate

		$expiredCerts = $allCerts | Where-Object {
			($_.CertificateExpirationdate -lt $ThresholdDate) -and
			(
				(-not $TemplateName) -or
				($_.CertificateTemplate -eq $TemplateName) -or
				($_.TemplateDisplayName -eq $TemplateName)
			)
		}

		$notExpiredCerts = $allCerts | Where-Object CertificateExpirationDate -GE $ThresholdDate | Where-Object {
			(-not $TemplateName) -or
			($_.CertificateTemplate -eq $TemplateName) -or
			($_.TemplateDisplayName -eq $TemplateName)
		}
		$alreadyRenewedExpiredCerts = $expiredCerts | Where-Object IssuedCommonname -In $notExpiredCerts.IssuedCommonname
		$renewalPendingCerts = $expiredCerts | Where-Object IssuedCommonname -NotIn $notExpiredCerts.IssuedCommonname
		$alreadyRenewedExpiredCerts | Add-Member -MemberType NoteProperty -Name CertStatus -Value Renewed -PassThru
		$renewalPendingCerts | Add-Member -MemberType NoteProperty -Name CertStatus -Value RenewalPending -PassThru
	}
}