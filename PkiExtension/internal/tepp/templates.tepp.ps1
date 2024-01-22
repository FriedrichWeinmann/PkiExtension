Register-PSFTeppScriptblock -Name 'PkiExtension.TemplateName' -ScriptBlock {
	$param = @{ }
	if ($fakeBoundParameter.Server) { $param.Server = $fakeBoundParameter.Server }
	elseif ($fakeBoundParameter.ComputerName -match '\.') {
		$param.Server = $fakeBoundParameter.ComputerName -replace '^.+?\.'
	}
	if ($fakeBoundParameter.Credential) { $param.Credential = $Credential }

	(Get-PkiTemplate @param).DIsplayName
} -Global