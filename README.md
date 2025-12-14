# Powershell-Scripts

A collection of PowerShell scripts for work and personal projects that I use to automate routine tasks.

## Table of contents
- [Prerequisites](#prerequisites)
- [Scripts](#scripts)
- [Configuration](#configuration)
- [Contributing](#contributing)
- [License](#license)

## Prerequisites
- PowerShell 7+ (recommended) or Powershell Core on Linux/Mac
- The module(s) noted in the script you want to run
- Appropriate Microsoft Graph permissions

## Scripts

- `Entra/Get-ExpiringCertsAndSecrets.ps1` — Checks enterprise applications for
	expiring certificates and application registrations for expiring client secrets,
    then orders them by soonest expiration.

## Configuration

- The scripts intentionally do not auto-install modules. Install required modules manually to
	control scope and avoid large imports.
- The Graph sign-in in these scripts uses interactive authentication. Other authentication methods may come in the future.

## Contributing

- Fork → branch → PR. Keep changes focused and add tests or examples for new scripts.

## License

- MIT License
