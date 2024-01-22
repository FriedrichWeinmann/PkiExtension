# Description

Welcome to the PKI Extension PowerShell module project.
We aim to provide quality tools to manage the Windows-Integrated PKI.

> This is very much a work in progress.

## Install

To install the module (and all its dependencies), run:

```powershell
# Classic
Install-Module PkiExtension -Scope CurrentUser

# PS 7.4+
Install-PSResource PkiExtension
```

## PSFramework Module

This is a [PSFramework](https://psframework.org)-based module.
It most notably relies on its logging capabilities to allow you to log all actions performed through this module and integrate it into your overall logging strategy.

## Profit

> Discovery

```powershell
# List all issued certificates
Get-PkiCaIssuedCertificate

# List all certificates of the template "Web Server vNext" from subca01
Get-PkiCaIssuedCertificate -ComputerName subca01 -TemplateName 'Web Server vNext'
```

> Expiration

```powershell
# List all issued certificates that will expire in the next 14 days and whether they have already been renewed
Get-PkiCaExpiringCertificate -FQCAName subca1\sub-ca-01 -TemplateName 'Web Server vNext'
```

> Revocation

```powershell
# Revoke all issued "XYZ Web Frontend Server" certificates due to Cessation of Operation
Get-PkiCaIssuedCertificate -ComputerName ServiceCA01 -TemplateName 'XYZ Web Frontend Server' | Revoke-PkiCaCertificate -ComputerName ServiceCA01 -Reason CessationOfOperation -Confirm:$false
```