function Revoke-PkiCaCertificate {
	<#
	.SYNOPSIS
		Revokes a certificate.
	
	.DESCRIPTION
		Revokes a certificate.
	
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
	
	.PARAMETER Certificate
		The certificate to revoke.
		Can be a plain certificate object (X509Certificate2) or the result of Get-PkiCaIssuedCertificate.
	
	.PARAMETER Reason
		Why the certificate is being revoked.
		Defaults to "Unspecified"

	.PARAMETER RevocationDate
		Starting when the certificate is considered invalid.
	
	.PARAMETER EnableException
		This parameters disables user-friendly warnings and enables the throwing of exceptions.
		This is less user friendly, but allows catching exceptions in calling scripts.

	.PARAMETER WhatIf
		If this switch is enabled, no actions are performed but informational messages will be displayed that explain what would happen if the command were to run.
	
	.PARAMETER Confirm
		If this switch is enabled, you will be prompted for confirmation before executing any operations that change state.
	
	.EXAMPLE
		PS C:\> Get-PkiCaIssuedCertificate | Revoke-PkiCaCertificate

		Create havoc.
		Revokes all issued certificates from the local CA.
		NOTE: THIS IS USUALLY A BAD IDEA!

	.EXAMPLE
		PS C:\> Revoke-PkiCaCertificate -Certificate $cert -Computername ca.contoso.com

		Revokes the certificate stored from the CA on ca.contoso.com
	#>
	[CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'High')]
	Param (
		[PSFComputer]
		$ComputerName = $env:COMPUTERNAME,

		[pscredential]
		$Credential,

		[string]
		$FQCAName,
      
		[Parameter(Mandatory = $true, ValueFromPipeline = $true)]
		$Certificate,

		[ValidateSet('Unspecified', 'KeyCompromise', 'CACompromise', 'AffiliationChanged', 'Superseded', 'CessationOfOperation', 'CertificateHold')]
		[string]
		$Reason = 'Unspecified',

		[DateTime]
		$RevocationDate = [DateTime]::Now,

		[switch]
		$EnableException
	)

	begin {
		$reasonCodes = @{
			Unspecified          = 0
			KeyCompromise        = 1
			CACompromise         = 2
			AffiliationChanged   = 3
			Superseded           = 4
			CessationOfOperation = 5
			CertificateHold      = 6
		}

		$param = $PSBoundParameters | ConvertTo-PSFHashtable -Include ComputerName, Credential

		$result = Resolve-Fqca -ComputerName $ComputerName -Credential $Credential -FQCAName $FQCAName
		if (-not $result.Success) {
			Stop-PSFFunction -String 'Revoke-PkiCaCertificate.Error.FqcaNotResolved' -StringValues $ComputerName, $result.Error -Cmdlet $PSCmdlet -EnableException $EnableException -Category ObjectNotFound
			return
		}
		$caName = $result.FQCA
	}
	process {
		if (Test-PSFFunctionInterrupt) { return }

		ForEach ($certificateObject in $Certificate) {
			$currentItem = $null
			if ($certificateObject -is [System.Security.Cryptography.X509Certificates.X509Certificate2]) {
				$currentItem = $certificateObject
			}
			elseif ($certificateObject.certificate -is [System.Security.Cryptography.X509Certificates.X509Certificate2]) {
				$currentItem = $certificateObject.Certificate
			}
			else {
				Stop-PSFFunction -String "Revoke-PkiCaCertificate.Error.NotACertificate" -StringValues $certificateObject -EnableException $EnableException -Continue -Target $certificateObject
			}

			$config = @{
				FQCA           = $caName
				SerialNumber   = $currentItem.SerialNumber
				Reason         = $reasonCodes[$Reason]
				RevocationDate = $RevocationDate.ToUniversalTime()
			}

			Invoke-PSFProtectedCommand -ActionString 'Revoke-PkiCaCertificate.Revoking' -ActionStringValues $currentItem.Subject, $currentItem.NotAfter, $caName -Target $currentItem -ScriptBlock {
				Invoke-PSFCommand @param -ErrorAction Stop -ScriptBlock {
					param ($Config)
					try { $COMcertAdmin = New-Object -ComObject CertificateAuthority.Admin }
					catch { throw "Failed to load PKI Com Object. Ensure the PKI Admin tools are installed correctly! $_" }
					try { $COMcertAdmin.RevokeCertificate($Config.FQCA, $Config.SerialNumber, $Config.Reason, $Config.RevocationDate) }
					catch { throw "Failed to revoke certificate $($Config.SerialNumber) against $($Config.FQCA)"}
					finally { $null = [System.Runtime.Interopservices.Marshal]::ReleaseComObject($COMcertAdmin) }
				} -ArgumentList $config
			} -EnableException $EnableException -PSCmdlet $PSCmdlet -Continue
		}
	}
}