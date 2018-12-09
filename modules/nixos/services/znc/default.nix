{ config, lib, pkgs, ...}:

with lib;

let
  cfg = config.services.newznc;


  # Converts a semantic config to a string
  semanticToString = cfg: let

    getAttrs = set: sort (a: b:
      # Attributes should be last
      if a == "extraConfig"
        then false # Always put extraConfig last
        else if builtins.isAttrs set.${a}
        # Attributes should be last
        then if builtins.isAttrs set.${b} then a < b else false
        else if builtins.isAttrs set.${b} then true else a < b
    ) (builtins.attrNames set);

        toLines = set: flatten (map (name: let
          value = set.${name};
          atom = val: {
            bool = "${name} = ${if val then "true" else "false"}";
            string = if name == "extraConfig" then val else "${name} = ${val}";
              int = "${name} = ${toString val}";
              null = [];
          };
              forType = atom value // {

                set = map (subname: let
                  subvalue = value.${subname};
                in if subvalue == null then [] else [
                  "<${name} ${subname}>"
                (map (line: "\t${line}") (toLines subvalue))
                  "</${name}>"
                ]) (builtins.attrNames value);

                  list = map (elem: (atom elem).${builtins.typeOf elem}) value;

              }; in
                  forType.${builtins.typeOf value}
        ) (getAttrs set));

  in concatStringsSep "\n" (toLines cfg);

              semanticTypes = with types; rec {
                zncAtom = either (either int bool) str;
                zncList = listOf zncAtom;
                zncAttr = attrsOf (nullOr zncConf);
                zncAll = nullOr (either (either zncAtom zncList) zncAttr);
                zncConf = attrsOf (zncAll // {
                  description = "znc values (null, atoms (str, int, bool), list of atoms, or attrsets of znc values)";
                });
              };

              defaultUser = "znc";

              modules = pkgs.buildEnv {
                name = "znc-modules";
                paths = cfg.modulePackages;
              };

in

            {

              imports = [
                ./opts.nix
              ];

              options = {
                services.newznc = {
                  enable = mkOption {
                    default = false;
                    type = types.bool;
                    description = ''
                      Enable a ZNC service for a user.
                    '';
                  };

                  config = mkOption {
                    type = semanticTypes.zncConf;
                    apply = value: {
                      Version = (builtins.parseDrvName pkgs.znc.name).version;
                    } // value;
                    example = literalExample ''
                      {
                      Listener.l = {
                      IPv4 = true;
                      IPv6 = true;
                      Port = 5000;
                      SSL = true;
                      };
                      LoadModule = [ "webadmin" "adminlog" ];
                      User.znc = {
                      Admin = true;
                      Nick = "znc-user";
                      AltNick = "znc-user_";
                      Ident = "znc-user";
                      RealName = "znc-user";
                      LoadModule = [ "chansaver" "controlpanel" ];
                      Network.freenode = {
                      Server = "chat.freenode.net +6697";
                      LoadModule = [ "simple_away" ];
                      Chan = {
                      "#nixos" = {};
                      "##programming" = {};
                      };
                      };
                      Pass.password = {
                      Method = "sha256";
                      Hash = "e2ce303c7ea75c571d80d8540a8699b46535be6a085be3414947d638e48d9e93";
                      Salt = "l5Xryew4g*!oa(ECfX2o";
                      };
                      };
                      }
                    '';
                    description = ''
                      Configuration for ZNC, see https://wiki.znc.in/Configuration for details. The Nix value declared here will be translated directly to the xml-like format ZNC expects.
                      </para>
                      <para>
                      Nix attributes called <literal>extraConfig</literal> will be inserted verbatim into the resulting config file. The only value that will be added by default is the "Version" key which will be set to the correct znc version.
                      </para>
                      <para>
                      Setting this option will override the default one generated by the old <option>confOptions</option> options. This new option allows you use an arbitrary ZNC configuration, whereas the old one is limited to the implemented options.
                    '';
                  };

                  configFile = mkOption {
                    type = types.path;
                    example = literalExample "~/.znc/configs/znc.conf";
                    description = ''
                      Configuration file for ZNC. Recommended is to use the <option>config</option> option instead.
                      </para>
                      <para>
                      This option can have multiple sources (higher up overrides lower ones):
                      <itemizedlist>
                      <listitem><para>
                      Setting this value directly to a file.
                      </para></listitem>
                      <listitem><para>
                      Setting the <option>zncConf</option> option to use its value as the files contents (backwards compatibility).
                      </para></listitem>
                      <listitem><para>
                      Setting the <option>config</option> option to convert it to an equivalent file.
                      </para></listitem>
                      <listitem><para>
                      And as a fallback, the <option>confOptions</option> option will be used to generate a file (backwards compatibility).
                      </para></listitem>
                      </itemizedlist>
                    '';
                  };

                  user = mkOption {
                    default = "znc";
                    example = "john";
                    type = types.string;
                    description = ''
                      The name of an existing user account to use to own the ZNC server process.
                      If not specified, a default user will be created to own the process.
                    '';
                  };

                  group = mkOption {
                    default = "";
                    example = "users";
                    type = types.string;
                    description = ''
                      Group to own the ZNCserver process.
                    '';
                  };

                  dataDir = mkOption {
                    default = "/var/lib/znc/";
                    example = "/home/john/.znc/";
                    type = types.path;
                    description = ''
                      The data directory. Used for configuration files and modules.
                    '';
                  };

                  openFirewall = mkOption {
                    type = types.bool;
                    default = false;
                    description = ''
                      Whether to open ports in the firewall for ZNC.
                    '';
                  };

                  modulePackages = mkOption {
                    type = types.listOf types.package;
                    example = literalExample "with pkgs.zncModules; [ fish push ]";
                    description = ''
                      A list of global znc module packages to add to ZNC. As these are really small, by default all ZNC modules in nixpkgs are included.

                      Note that by default ZNC has a lot of modules included already (see https://wiki.znc.in/Modules#Module_List). This option is only needed for external ones.
                    '';
                  };

                  mutable = mkOption {
                    default = true;
                    type = types.bool;
                    description = ''
                      Indicates whether to allow the contents of the `dataDir` directory to be changed
                      by the user at run-time.
                      If true, modifications to the ZNC configuration after its initial creation are not
                      overwritten by a NixOS system rebuild.
                      If false, the ZNC configuration is rebuilt by every system rebuild.
                      If the user wants to manage the ZNC service using the web admin interface, this value
                      should be set to true.
                    '';
                  };

                  extraFlags = mkOption {
                    default = [ ];
                    example = [ "--debug" ];
                    type = types.listOf types.str;
                    description = ''
                      Extra flags to use when executing znc command.
                    '';
                  };
                };
              };


              ###### Implementation

              config = mkIf cfg.enable {

                services.newznc = {
                  configFile = mkDefault (pkgs.writeText "znc.conf" (semanticToString cfg.config));
                  modulePackages = mkDefault (filter (x: isDerivation x) (builtins.attrValues pkgs.zncModules));
                };

                networking.firewall = mkIf cfg.openFirewall {
                  allowedTCPPorts = flatten (map (l: l.Port or []) (builtins.attrValues (cfg.config.Listener or {})));
                };

                systemd.services.newznc = {
                  description = "ZNC Server";
                  wantedBy = [ "multi-user.target" ];
                  after = [ "network.target" ];
                  serviceConfig = {
                    User = cfg.user;
                    Group = cfg.group;
                    Restart = "always";
                    ExecStart = "${pkgs.znc}/bin/znc --foreground --datadir ${cfg.dataDir} ${toString cfg.extraFlags}";
                    ExecReload = "${pkgs.coreutils}/bin/kill -HUP $MAINPID";
                    ExecStop   = "${pkgs.coreutils}/bin/kill -INT $MAINPID";
                  };
                  preStart = ''
                    filepath="${cfg.dataDir}/configs/znc.conf"
                    mkdir -p "$(dirname "$filepath")"

                    # If mutable, regenerate conf file every time.
                    ${optionalString (!cfg.mutable) ''
                      echo "znc is set to be system-managed. Now deleting old znc.conf file to be regenerated."
                      rm -f "$filepath"
                    ''}

                    # Ensure essential files exist.
                    if [[ ! -f "$filepath" ]]; then
                    echo "No znc.conf file found in ${cfg.dataDir}. Creating one now."
                    cp --no-clobber "${cfg.configFile}" "$filepath"
                    chmod u+rw "$filepath"
                    chown ${cfg.user} "$filepath"
                    fi

                    if [[ ! -f "${cfg.dataDir}/znc.pem" ]]; then
                    echo "No znc.pem file found in ${cfg.dataDir}. Creating one now."
                    ${pkgs.znc}/bin/znc --makepem --datadir "${cfg.dataDir}"
                    fi

                    # Symlink modules
                    rm "${cfg.dataDir}/modules" || true
                    ln -fs "${modules}/lib/znc" "${cfg.dataDir}/modules"
                  '';
                };

                users.users = optional (cfg.user == defaultUser)
                { name = defaultUser;
                  description = "ZNC server daemon owner";
                  group = defaultUser;
                  uid = config.ids.uids.znc;
                  home = cfg.dataDir;
                  createHome = true;
                };

                  users.groups = optional (cfg.user == defaultUser)
                  { name = defaultUser;
                    gid = config.ids.gids.znc;
                    members = [ defaultUser ];
                  };

              };
            }
