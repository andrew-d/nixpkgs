{ config, lib, pkgs, ... }:

with lib;

let

  cfg = config.services.watchdog;

in

{

  ###### interface

  options = {

    services.watchdog = {
      enable = mkOption {
        type = types.bool;
        default = true;
        description = "Whether to enable the Linux software watchdog service.";
      };

      config = mkOption {
        type = types.lines;
        default = builtins.readFile ./watchdog.conf;
        description = "Configuration to use for the watchdog service.";
      };

      watchdogServices = mkOption {
        default = [];
        example = [ "rsyslog.service" ];
        type = types.listOf types.str;
        description = ''
          List of services that watchdog should wait for.

          This is useful to ensure that all required services are up before the
          watchdog main process starts, to ensure that there are no race
          conditions between service start and watchdog checks running.
        '';
      };
    };

  };


  ###### implementation

  config = mkIf cfg.enable {

    environment.etc."watchdog.conf".text = cfg.config;

    # From the man pages:
    #
    #     This is a simplified version of the daemon. Unlike the full watchdog,
    #     this daemon run no tests and only serves to keep the hardware timer
    #     refreshed. Typically this is used on system start-up to provide
    #     protection before the services that the full version tests are
    #     running, and on shutdown to continue the refresh while those services
    #     are stopped.
    systemd.services.wd_keepalive = {
      description = "Watchdog keepalive daemon";

      before    = [ "watchdog.service" "shutdown.target" ];
      conflicts = [ "watchdog.service" "shutdown.target" ];

      serviceConfig = {
        ExecStartPre = [
          "-${pkgs.systemd}/bin/systemctl reset-failed watchdog.service"
        ];
        ExecStart = "${pkgs.watchdog}/bin/wd_keepalive";

        Type = "forking";
        PIDFile = "/run/wd_keepalive.pid";
      };
    };

    # This is the main watchdog service.
    systemd.services.watchdog = {
      description = "Linux software watchdog";

      after     = [ "multi-user.target" ] ++ cfg.watchdogServices;
      conflicts = [ "wd_keepalive.service" ];
      onFailure = [ "wd_keepalive.service" ];

      serviceConfig = {
        ExecStart = "${pkgs.watchdog}/bin/watchdog";

        Type = "forking";
        PIDFile = "/run/watchdog.pid";
      };
    };

  };
}
