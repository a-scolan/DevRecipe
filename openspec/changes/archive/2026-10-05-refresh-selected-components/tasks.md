## 1. Provider fixtures and installed-state planning

- [x] 1.1 Extend Windows fake providers with checked Scoop catalogs, update results, Mise release versions, remote runtime versions, and binary provenance. Make sure that the fixtures log exact arguments and operation order.
- [x] 1.2 Separate approved selected entries, concrete exact-version no-install matches, supported floating update candidates, and declined conflicts in Windows preflight. Add regressions for installed `latest`, prefixes, matching requested aliases, exact pins, declined entries, and unchanged container exclusions.
- [x] 1.3 Preserve installed-state semantics for status and removal. Run the existing Windows version-match, status, and removal cases and make sure that update checks do not change their outputs or writes.
- [x] 1.4 Classify concrete pins and supported partial versions, explicit prefixes, and backend aliases using verified Mise semantics. Test `22`, `prefix:22`, `lts`, exact releases, and opaque backend versions without treating every non-`latest` request as a pin.
- [x] 1.5 Reject unsupported NPM range arguments and unmanaged special selectors before host mutation. Test `^22`, `~22`, `22.*`, `path:`, `system`, source references, and unsupported scopes with actionable errors and zero writes.

## 2. Scoped provider maintenance

- [x] 2.1 Add checked Scoop self-update and catalog refresh after decisions and review startup, with provider bootstrap, declared buckets, and the approved Git prerequisite. Test a fresh host, unavailable Git, self-update failure, catalog failure, no approved entries, and refresh-before-resolution order.
- [x] 2.2 Maintain installed or required Scoop-managed Mise once per approved standard installation run, even without runtime work. Test duplicate Mise requests, PATH shadowing, an external provider, an explicit Mise pin, and command re-resolution after update.
- [x] 2.3 Enforce Mise 2026.10.1 or later for approved selected Node work. Test older, minimum, newer, multi-digit, malformed, and prerelease versions, plus a catalog that cannot supply the minimum.
- [x] 2.4 Keep provider maintenance active for already-installed exact Mise runtimes without updating those runtimes. Test fixed Node with outdated Mise, a compatible provider, and a declined Node conflict.
- [x] 2.5 Prove that provider maintenance runs when every selected component is already installed or current. Test Scoop-only selections with installed Mise, absent unneeded Mise, repeated runs, and fully declined selections without unnecessary bootstrap or forced reinstalls.

## 3. Selected package and runtime updates

- [x] 3.1 Resolve every installed selected approved Scoop `latest` package against refreshed metadata and update exact raw IDs only. Test a fully installed selected list with several updates, newer, current, missing, fixed, declined, and unselected packages and reject wildcard update calls.
- [x] 3.2 Resolve selected supported floating Mise specifications with fresh provider metadata and install only missing resolved versions. Test Node and an `npm:` tool, `latest`, `22`, `prefix:22`, a moving `lts` alias, older installed versions, current versions, and resolution failure.
- [x] 3.3 Report checked installation and update outcomes and stop on failed queries or writes. Test unavailable inventories, failed updates, and post-install version mismatches without a success-shaped result.
- [x] 3.4 Preserve older runtime installations and global or project Mise version selection. Make sure that provider logs contain no broad upgrade, prune, forced reinstall, or `mise use` calls.
- [x] 3.5 Preserve each floating selector in resolution and installation commands. Test that `node@22` and `node@prefix:22` never become `node@latest`, and that a matching requested alias does not bypass fresh resolution.

## 4. Fixed shims and Node IPC checks

- [x] 4.1 Force-rebuild Mise-owned shims after provider replacement or approved selected Node work. Test an existing stale shim with already-current Mise and preserve PATH, shell, and AutoRun idempotence.
- [x] 4.2 Add a bounded IPC probe with an underlying Node parent and the actual absolute user shim as the child. Test matching replies, spawn errors, early exit, broken channels, and timeout with distinct reported failures.
- [x] 4.3 Report the installed manifest Node version separately from the shim's resolved executable and version. Test different configured versions and missing version selection without writing global or project configuration.
- [x] 4.4 Remove probe artifacts and terminate only its tracked process tree on every exit path. Test success and timeout cleanup and make sure that unrelated Node processes are untouched.

## 5. Plans, review, and unchanged routes

- [x] 5.1 Show Scoop self-update, catalog refresh, installed or required Mise maintenance, conditional exact-ID updates, forced shim rebuild, and Node verification in Windows dry run. Test a fully installed list, provisional catalog labels, and the absence of mutating calls or host file changes.
- [x] 5.2 Route each new write through existing review checkpoints. Test refusal before refresh or update and accepted individual action ordering.
- [x] 5.3 Preserve `-Force` conflict semantics and keep maintenance and compatibility checks under `-SkipPreflight`. Test both flags without forced reinstalls or wildcard updates.
- [x] 5.4 Keep validation and listing manifest-only and add no update writes to status, removal, the container bundle, or Unix. Run the affected existing mode and cross-platform cases.

## 6. Documentation and integration evidence

- [x] 6.1 Update the README, installation reference, preflight reference, and Windows manual validation guide. Document provider self-maintenance on repeated runs, all selected installed Scoop updates, supported floating Mise selectors, unsupported NPM arguments, preserved pins, provider ownership, no global version selection, and partial-failure behavior.
- [x] 6.2 Run the existing developer gate and targeted Windows acceptance cases, then the full local quality gate. Record results and separate unavailable-platform skips from passes.
- [x] 6.3 On a disposable Windows host, test the native shim IPC exchange with a fixed Mise release and rebuilt shim. Demonstrate the stale-shim negative control when an affected release is available and record the exact versions and results.
- [x] 6.4 Run strict OpenSpec validation and compare implementation behavior with every added or modified scenario before marking the change complete.
