# pia-nix

This is primarily made for personal use, but should be usable by others.

The primary use case is having a dedicated network namespace for services that should have their traffic routed through PIA. There is also support for updating the "incoming port" setting of some torrent clients.

## rTorrent

To have rTorrent apply the port forward, you might want to have something like this in your rTorrent config:

    schedule2 = watch_port, 3, 10, ((try_import, "/tmp/pia.port.rtorrent"))
