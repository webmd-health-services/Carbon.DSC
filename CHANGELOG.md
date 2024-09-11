
# Carbon.DSC Changelog

## 1.0.0

### Upgrade Instructions

Migrated DSC functionality from Carbon.

* Update usages of the `Initialize-CLcm` function's `CertPassword` parameter to be a `[SecureString]` object.

### Changed

* The `Initialize-CLcm` function's `CertPassword` parameter is now a `[SecureString]`. Previously, plaintext strings
were allowed.