{ pkgs, lib, config, ... }:

let
  cfg = config.services.pia-wg;
  script = src:
    let
      name = builtins.baseNameOf (builtins.toString src);
      pkg = pkgs.symlinkJoin {
        name = name;
        paths =
          [ (pkgs.writeShellScriptBin name (builtins.readFile src)) ] ++
          (with pkgs; [ inetutils iproute2 wireguard-tools curl jq gnugrep coreutils gawk ]);
        buildInputs = [ pkgs.makeWrapper ];
        postBuild = "wrapProgram $out/bin/${name} --prefix PATH : $out/bin";
      };
    in
    "${pkg}/bin/${name}";
in
{
  options.services.pia-wg = with lib.types;
    {
      enable = lib.mkEnableOption "pia-wg";

      username = lib.mkOption {
        description = "PIA username";
        type = str;
      };

      password = lib.mkOption {
        description = "PIA password";
        type = nullOr str;
        default = null;
      };

      passwordFile = lib.mkOption {
        description = "Path to a file containing the PIA password";
        type = nullOr str;
        default = null;
      };

      passwordCommand = lib.mkOption {
        description = "Command to run to obtain the PIA password";
        type = nullOr str;
        default = null;
      };

      region = lib.mkOption {
        description = "PIA region to connect to";
        type = str;
        default = "finland";
      };

      interface = lib.mkOption {
        description = "Wireguard network interface name";
        type = str;
        default = "pia";
      };

      netns = lib.mkOption {
        description = "Network namespace name";
        type = str;
        default = "pia";
      };

      services = lib.mkOption {
        description = "Systemd services to put into the PIA network namespace";
        type = listOf str;
        default = [ ];
      };

      nat = lib.mkOption {
        description = "TCP ports to forward from the main network namespace to the PIA network namespace";
        type = listOf port;
        default = [ ];
      };

      portForwarding.enable = lib.mkEnableOption "port forwarding";

      portForwarding.transmission = {
        enable = lib.mkEnableOption "Transmission port update";
        url = lib.mkOption {
          description = "Transmission RPC endpoint URL";
          type = str;
          default = "http://127.0.0.1:${builtins.toString config.services.transmission.settings.rpc-port}/transmission/rpc";
        };
        username = lib.mkOption {
          description = "Transmission RPC endpoint username, if authentication if enabled";
          type = str;
          default = "";
        };
        password = lib.mkOption {
          description = "Transmission RPC endpoint password, if authentication if enabled";
          type = str;
          default = "";
        };
      };
    };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = with cfg; lib.count (x: x != null) [ password passwordFile passwordCommand ] == 1;
        message = "Exactly one of services.pia-wg.{password, passwordFile, passwordCommand} must be non-null.";
      }
    ];

    systemd.services = builtins.listToAttrs
      (
        builtins.map
          (port: {
            name = "pia-wg-nat-${builtins.toString port}";
            value = {
              wantedBy = [ "multi-user.target" ];
              after = [ "pia-wg.service" ];
              wants = [ "pia-wg.service" ];
              serviceConfig = {
                User = "root";
                Restart = "on-failure";
                Type = "simple";
                ExecStart = ''${pkgs.socat}/bin/socat tcp-listen:${builtins.toString port},fork,reuseaddr exec:'${pkgs.iproute2}/bin/ip netns exec ${cfg.netns} ${pkgs.socat}/bin/socat STDIO "tcp-connect:127.0.0.1:${builtins.toString port}"',nofork'';
              };
            };
          })
          cfg.nat
      ) // builtins.listToAttrs (
      builtins.map
        (
          service: {
            name = service;
            value = {
              after = [ "pia-wg.service" "pia-wg-pf.service" ];
              wants = [ "pia-wg.service" ];
              serviceConfig.NetworkNamespacePath = "/var/run/netns/${cfg.netns}";
            };
          }
        )
        cfg.services
    ) // {
      pia-wg = {
        wantedBy = [ "multi-user.target" ];
        after = [ "network-online.target" ];
        wants = [ "network-online.target" ];
        serviceConfig = {
          Restart = "on-failure";
          RestartSec = "1s";
          Type = "oneshot";
          ExecStart = script ./pia-up.sh;
          ExecStopPost = script ./pia-down.sh;
          RemainAfterExit = "yes";
        };
        environment = {
          PIA_CERT = ./ca.rsa.4096.crt;
          PIA_USER = cfg.username;
          PIA_PASS = cfg.password;
          PIA_PASS_FILE = cfg.passwordFile;
          PIA_PASS_CMD = cfg.passwordCommand;
          PIA_REGION = cfg.region;
          PIA_INTERFACE = cfg.interface;
          PIA_NETNS = cfg.netns;
        };
      };
      pia-wg-pf = lib.mkIf cfg.portForwarding.enable {
        wantedBy = [ "multi-user.target" ];
        after = [ "pia-wg.service" "transmission.service" ];
        bindsTo = [ "pia-wg.service" ];
        serviceConfig = {
          Restart = "on-failure";
          RestartSec = "10s";
          Type = "simple";
          ExecStart = script ./pia-pf.sh;
          NetworkNamespacePath = "/var/run/netns/${cfg.netns}";
        };
        environment = {
          PIA_CERT = ./ca.rsa.4096.crt;
          TRANSMISSION_URL = if cfg.portForwarding.transmission.enable then cfg.portForwarding.transmission.url else "";
          TRANSMISSION_USERNAME = cfg.portForwarding.transmission.username;
          TRANSMISSION_PASSWORD = cfg.portForwarding.transmission.password;
        };
      };
    };
  };
}
