# Changelog

All notable changes to this module are documented here. Format loosely follows [Keep a Changelog](https://keepachangelog.com/).

## [Unreleased]

### Changed — `team` is required and must be a team code
Breaking: `var.team` no longer defaults to `infra-core`; it must be
`team-NNNN`, a row in `aj-infra/envs/org/teams.yaml`. Every consumer in the
estate already passes one (`team = "team-0001"` in aj-infra's tfvars since
2026-09-12), so nothing changes for them; a caller that forgot would have
tagged resources — and labelled namespaces — with a slug nobody registered,
which `require-product-code` now refuses at admission. Next tag is a major.


### Fixed
- `README.md`'s "Provider pins" table said Terraform `= 1.7.5` — `providers.tf` actually pins `= 1.10.5`, matching the platform-wide Terraform 1.10.5 migration already reflected everywhere else. Same stale-version pattern already found and fixed in every other `aj-tf-module-*` repo touched this project.
- `skills.md`'s "Stable ref" pointed at `github.com/ajaylakma/aj-tf-module-vpn?ref=vpn-01` — wrong org (real org is `ajay-infra`) and a branch that doesn't exist (only `main` — confirmed via `git branch -a`; no tags existed either, despite `README.md`'s own Usage example already correctly referencing `?ref=v0.1.0`, also nonexistent). Fixed both refs to `v1.0.0` and cut that tag (module was fully implemented with no prior release).
- `skills.md`'s "AWS tags applied" listed `Env`, `Team`, `ManagedBy`, `CostCenter`, `Model`, `Customer` — checked `locals.tf`: the real tag set is `Project`/`ManagedBy`/`Repository`/`Environment`/`Team`/`CostCenter` (from `locals.full_tags`) plus whatever's in `var.tags`. No `Env`, `Model`, or `Customer` tag exists anywhere in this module. Same copy-paste pattern already found in several other modules this project.

## [v1.0.0] - 2026-08-24

Initial release — AWS Client VPN endpoint, mTLS + optional AD auth, split-tunnel routing, CloudWatch connection logs. Module was already fully implemented; this tag just formalizes the first stable release so `README.md`/`skills.md` have something real to pin to.
