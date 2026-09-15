# Synthetic package fixture

These `.pck` files contain plain text, not Godot exports. They deliberately test only package metadata, content integrity, and library installation. Do not use this fixture to claim that a game launches or passes certification.

Each OS/architecture variant has its own filename. `release.json` records the exact byte size and SHA-256 digest. The fixture is small enough to use in tests without downloading an engine or game assets.
