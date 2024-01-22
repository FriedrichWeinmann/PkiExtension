function Resolve-Fqca {
	<#
	.SYNOPSIS
		Resolves the fully qualified CA Name of the specified CA.
	
	.DESCRIPTION
		Resolves the fully qualified CA Name of the specified CA.
		If an FQCA is specified, it will just return it without verification.
		Otherwise it will try to use the ComputerName and PSRemoting to read the CA name from the service configuration.

		This command will never generate an error.
	
	.PARAMETER ComputerName
		Name of the computer hosting the CA
	
	.PARAMETER Credential
		Credentials to use for the remoting lookup.
	
	.PARAMETER FQCAName
		The fully qualified CA Name.
	
	.EXAMPLE
		PS C:\> Resolve-Fqca -ComputerName $ComputerName -Credential $Credential -FQCAName $FQCAName

		Resolves the FQCA of the specified CA.
	#>
	[CmdletBinding()]
	param (
		[AllowNull()]
		[PSFComputer]
		$ComputerName,

		[AllowNull()]
		[PSCredential]
		$Credential,

		[AllowEmptyString()]
		[string]
		$FQCAName
	)
	process {
		if (-not ($ComputerName -or $FQCAName)) {
			[PSCustomObject]@{
				Success = $false
				Name    = $null
				FQCA    = $null
				Error   = 'Neither ComputerName nor FQCA were specified!'
			}
			return
		}

		if ($FQCAName) {
			[PSCustomObject]@{
				Success = $true
				Name    = $FQCAName -replace '^.+?\\'
				FQCA    = $FQCAName
				Error   = $null
			}
			return
		}

		$code = {
			$result = [PSCustomObject]@{
				Success = $false
				Name    = $null
				FQCA    = $null
				Error   = $null
			}
			try { $result.Name = (Get-ItemProperty -Path 'HKLM:\System\CurrentControlSet\Services\CertSvc\Configuration' -Name Active -ErrorAction Stop).Active }
			catch {
				$result.Error = $_
				return $result
			}
			$result.FQCA = "$($env:COMPUTERNAME)\$($result.Name)"
			$result.Success = $true
			$result
		}

		$param = @{ }
		if ($ComputerName) { $param.ComputerName = $ComputerName }
		if ($Credential) { $param.Credential = $Credential }
		
		try { Invoke-PSFCommand @param -ErrorAction Stop -ScriptBlock $code }
		catch {
			[PSCustomObject]@{
				Success = $false
				Name    = $null
				FQCA    = $null
				Error   = $_
			}
		}
	}
}