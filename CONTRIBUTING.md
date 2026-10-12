# Contributing to ForeverVendors

Contributions are welcome when they preserve database safety and item accuracy.

## Rules for vendor changes

- Verify every item ID in the installed ForeverRepack database.
- Verify curated replacements against Wowhead's Forever section or another
  authoritative Forever-compatible source.
- Never assume retail, Classic, WotLK or Cataclysm IDs are interchangeable.
- Keep custom creature and spawn IDs inside the documented reserved ranges unless
  a migration and removal path are included.
- Do not reference gossip scripts, trainers or C++ modules absent from ForeverRepack.
- Regenerate the audit and review the SQL diff after every catalogue change.
- Include a removal path for new database rows.

## Development workflow

1. Fork the repository and branch from `main`.
2. Start the ForeverRepack database, not worldserver.
3. Back up `world` before any import test.
4. Run the builder against the intended repack version.
5. Inspect `FOREVER_VENDOR_AUDIT.md` and both generated SQL scripts.
6. Import into a disposable database first, then start worldserver and test every
   changed vendor in game.

## Pull requests

State the repack version, changed vendor IDs, source used for item validation and
the before/after row counts. Attach sanitized SQL results or in-game screenshots.
Do not include database passwords, private server addresses or player data.

Contributions to the FilinoDZ-authored portions are submitted under the MIT terms
in `LICENSE.md`. Preserve all legacy and third-party credits.
