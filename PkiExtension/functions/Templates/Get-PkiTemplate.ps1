function Get-PkiTemplate {
	<#
	.SYNOPSIS
		Retrieve templates from Active Directory.
	
	.DESCRIPTION
		Retrieve templates from Active Directory.
		Templates are stored forest-wide and selectively made available to CAs.
		This command retrieves the global list.
	
	.PARAMETER Server
		The domain or server to contact.
	
	.PARAMETER Credential
		The credential to use for the request.
	
	.EXAMPLE
		PS C:\> Get-PkiTemplate

		Retrieve all templates from the current forest.
	#>
	[CmdletBinding()]
	param (
		[string]
		$Server,

		[PSCredential]
		$Credential
	)
	process {
		$param = $PSBoundParameters | ConvertTo-PSFHashtable -ReferenceCommand Get-LdapObject
		$param.LdapFilter = '(objectClass=pKICertificateTemplate)'
		$param.TypeName = 'PkiExtension.Template'
		$param.Configuration = $true
		$param.TypeName = 'PkiExtension.Template'
		Get-LdapObject @param
	}
}