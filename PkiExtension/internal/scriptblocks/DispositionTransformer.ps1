Register-PSFArgumentTransformationScriptblock -Name 'PkiExtension.Disposition' -Scriptblock {
	$dispositions = @{
		Denied  = 31
		Failed  = 30
		Revoked = 21
		Issued  = 20
		Request = 9
	}
	if ($dispositions.Keys -contains $_) {
		$dispositions[$_]
	}
}