
# Carbon.DSC Changelog

## 1.0.0

### Upgrade Instructions

Migrated DSC functionality from Carbon.

* Minimum PowerShell version is now 5.1.
* Update usages of the `Initialize-CLcm` function's `CertPassword` parameter to be a `[SecureString]` object.

### Changed

* The `Initialize-CLcm` function's `CertPassword` parameter is now a `[SecureString]`. Previously, plaintext strings
were allowed.
