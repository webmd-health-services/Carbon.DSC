
# Carbon.DSC Changelog

## 1.1.0

* Added support to Carbon_Group resource for adding new members without removing any members.
* Added support to Carbon_Group resource for removing group members.

## 1.0.1

Reducing directory depth of internal, private nested module dependencies.

## 1.0.0

> Released 13 Sep 2024

### Upgrade Instructions

Migrated DSC functionality from Carbon.

* Minimum PowerShell version is now 5.1.
* Update usages of the `Initialize-CLcm` function's `CertPassword` parameter to be a `[SecureString]` object.

### Changed

* The `Initialize-CLcm` function's `CertPassword` parameter is now a `[SecureString]`. Previously, plaintext strings
were allowed.
