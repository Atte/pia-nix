# pia-nix

This is primarily made for personal use, but should be usable by others.

The primary use case is having a dedicated network namespace for services that should have their traffic routed through PIA. There is also support for updating the "incoming port" setting of some torrent clients.

## pia-up.sh env

    PIA_CERT = ./ca.rsa.4096.crt
    PIA_USER = PIA username
    PIA_PASS = PIA password
    PIA_PASS_FILE = path to file containing PIA password
    PIA_PASS_CMD = command to run to obtain PIA password
    PIA_REGION = PIA region to connect to
    PIA_INTERFACE = name of PIA wireguard interface
    PIA_NETNS = name of PIA network namespace

## pia-pf.sh env

Note that `pia-pf.sh` MUST be run in the PIA network namespace!

    PIA_CERT = ./ca.rsa.4096.crt;
    TRANSMISSION_URL = Transmission API URL, if you want automatic port updates
    TRANSMISSION_USERNAME = transmission API username, if required
    TRANSMISSION_PASSWORD = transmission API password, if required

## rTorrent

To have rTorrent apply the port forward, you might want to have something like this in your rTorrent config:

    schedule2 = watch_port, 3, 10, ((try_import, "/tmp/pia.port.rtorrent"))
