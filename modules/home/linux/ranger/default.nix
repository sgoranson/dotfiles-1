{ config, pkgs, lib, ... }:

with pkgs;
with lib;

let
  cfg = config.mine.ranger;
  deps = pkgs.unstable.callPackage (import ./deps.lib.nix) {};

  rc = builtins.replaceStrings
    ["/usr/share"
      "#set preview_script ~/.config/ranger/scope.sh"]

    ["${deps.ranger}/share"
      "set preview_script ${deps.ranger}/share/doc/ranger/config/scope.sh"]

    (readFile ./rc.conf);


in {
  options.mine.ranger.enable = mkEnableOption "ranger";

  config = mkIf cfg.enable {
    home.packages = [ deps.ranger ];
    home.file.".config/ranger/rc.conf".text = rc;
    home.file.".config/ranger/commands.py".source = ./commands.py;

    programs.zsh.sessionVariables = { RANGER_LOAD_DEFAULT_RC = "TRUE"; };

    programs.zsh.initExtra = ''
      if [ -n "$RANGER_LEVEL" ]; then
      TRAPINT() {
      kill $PPID
      }
      trap "pwd > /tmp/rangershelldir-$USER" EXIT
      fi
    '';
  };
}
