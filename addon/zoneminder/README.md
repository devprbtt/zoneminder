# ZoneMinder Home Assistant Add-on (Minimal)

This is a minimal starting point for running ZoneMinder as a Home Assistant custom add-on.

## Current scope

- Single-container setup with Apache + ZoneMinder + MariaDB
- Persistent data under add-on `/data`:
  - `/data/mysql`
  - `/data/events`
- Basic database bootstrap and schema import

## Add-on options

- `db_name`
- `db_user`
- `db_pass`
- `db_root_pass`
- `timezone`
- `events_path` (default `/data/events`, example `/media/EXTHDD/zoneminder/events`)

## Notes

- This first version is intentionally minimal and only advertises `amd64`.
- `host_network: true` is enabled for camera/RTSP compatibility.
- Apache/ZoneMinder web UI runs on host port `8088` (not `80`).
- `media` is mounted in the add-on, so external media shares are available at `/media/*`.
- `devices` currently maps `/dev/video0` as a starting point.
- Further hardening is expected (multi-arch, healthcheck, startup retries, and external DB mode).
