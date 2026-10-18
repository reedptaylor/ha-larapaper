# LaraPaper

Runs [LaraPaper](https://github.com/usetrmnl/larapaper), a self-hosted TRMNL server (BYOS),
on Home Assistant. The web UI and device API are on port **4567**.

## Options

| Option | What it does |
| --- | --- |
| `app_url` | Leave as `http://localhost`. LaraPaper then builds screen-image links from the address each request used, so devices and browsers can reach the server by different addresses. Any other value is used for every image link. |
| `app_key` | Laravel encryption key, e.g. the output of `echo "base64:$(openssl rand -base64 32)"`. Leave empty to use the image's built-in key, which is public. |
| `app_previous_keys` | Old keys, comma-separated, so data encrypted with them still decrypts after a key change. |

## Data

The SQLite database and generated screens live in this app's config folder (`/config`
inside the app), which Home Assistant includes in backups.

## Devices

Point TRMNL devices at `http://<home-assistant-address>:4567` in their Wi-Fi setup portal
(**Advanced → Custom Server**). Devices can't reach Tailscale addresses.
