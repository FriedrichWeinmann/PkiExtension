# This is where the strings go, that are written by
# Write-PSFMessage, Stop-PSFFunction or the PSFramework validation scriptblocks
@{
	'Revoke-PkiCaCertificate.Error.FqcaNotResolved' = 'Unable to resolve the fully qualified CA Name for {0}. Please ensure the target server is actually a CA and reachable! {0}' # $ComputerName, $result.Error
	'Revoke-PkiCaCertificate.Error.NotACertificate' = 'Certificate specified is not actually a certificate: {0}' # $certificateObject
	'Revoke-PkiCaCertificate.Revoking'              = 'Revoking the certificate {0} (NotAfter: {1}) against {2}' # $certificateObject.Subject, $certificateObject.NotAfter, $caName
}