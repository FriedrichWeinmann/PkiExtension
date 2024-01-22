# Intended Features

## Notes

Much certificate-/PKI-related tooling has already been created, but ...

+ Code quality varies wildly
+ Generally no integrated logging capabilities for something extremely sensitive
+ Most projects stop once their own use-case has been met (reasonable, but leaves feature gaps)
+ there exist significant holes in feature coverage

This project is going to be 'borrowing' from many other projects.
At least the ideas, that is, for the code will be created anew.

## List of Features

+ CA
  + Detection
  + Service Manager
  + Deployment (ZPki, PS-CryptoStudio)
  + Health & Security (Locksmith)
  + Issued Certificate Expiration Management (CATools)
+ Certificate Template Management
  + Creation
  + Retirement
  + Assignment
+ Enrollment (PSCertificateEnrollment)
+ Client-Side Certificates
  + Import / Export
  + Rights Management
  + Cert Store Management & Service Stores (ServiceCertStore)
  + Request Builder
  + Request Life-Cycle
  + Expiration Management

## Timeline

There is no solid timeline - it will happen when it will happen.

## Expectations / Assumptions about execution

> Global Assumptions

+ Is Executed from a domain-joined machine
+ Has AD Read Access
+ Can provide credentials to use*

> CA Component

+ Has certificate authority admin rights (Enterprise Admin or similar in most cases)
  + This will not be verified before execution, to allow custom delegation scenarios
+ Some operations may require PSRemoting against the server hosting the CA
  + These commands will accept a custom PSSession

> Certificate Template Component

+ Has certificate authority admin rights (Enterprise Admin or similar in most cases)
  + This will not be verified before execution, to allow custom delegation scenarios

> Enrollment Component

+ Has certificate authority admin rights (Enterprise Admin or similar in most cases) for the configuration parts.
  + This will not be verified before execution, to allow custom delegation scenarios
+ Local Admin Rights to the target machine for the Client Side operations
+ Elevated when executing against localhost

> Client-Side Certificate Component

+ Local Admin Rights
+ Elevated when executing against localhost
