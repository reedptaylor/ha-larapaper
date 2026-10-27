# LaraPaper for Home Assistant

A Home Assistant app repository for [LaraPaper](https://github.com/usetrmnl/larapaper), a
self-hosted TRMNL server (BYOS).

The app wraps the published `ghcr.io/usetrmnl/larapaper` image with a small startup hook
that keeps the database and generated screens in the app's config folder, so they're
included in Home Assistant backups. See [`larapaper/DOCS.md`](larapaper/DOCS.md) for options.

## Updates

A daily workflow checks for a new LaraPaper release and bumps the image tag and app version.
Home Assistant then shows the update like any other app. Turn on auto-update on the app page
to install it automatically.

To change the wrapper itself without a new LaraPaper release, add a fourth number to `version`
in `larapaper/config.yaml` (e.g. `0.45.0.1`) so Home Assistant sees an update. Don't use a
`-1` suffix: Home Assistant reads `0.45.0-1` as a pre-release, older than `0.45.0`.

## Adding the repository

This repository is private, so Home Assistant needs a read-only token to clone it:

1. Create a fine-grained GitHub token limited to this repository with
   **Contents: Read-only** access.
2. In Home Assistant, go to **Settings → Apps → App store → ⋮ → Repositories** and add
   `https://<token>@github.com/reedptaylor/ha-larapaper`.
