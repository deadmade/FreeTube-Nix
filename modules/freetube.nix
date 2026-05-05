{ lib, pkgs, config, ... }:

let
  inherit (lib)
    mkIf
    mkEnableOption
    mkPackageOption
    mkOption
    types
    literalExpression
    concatStrings
    concatMapStrings
    mapAttrsToList
    ;

  cfg = config.programs.freetube;

  settingsText = concatStrings (mapAttrsToList (name: value:
    builtins.toJSON { _id = name; inherit value; } + "\n"
  ) cfg.settings);

  profilesText = concatMapStrings (profile:
    builtins.toJSON profile + "\n"
  ) cfg.profiles;

  subscriptionType = types.submodule {
    options = {
      id = mkOption {
        type = types.str;
        description = "YouTube channel ID.";
      };
      name = mkOption {
        type = types.str;
        description = "Human-readable channel name.";
      };
      thumbnail = mkOption {
        type = types.str;
        default = "";
        description = "URL to the channel thumbnail (may be left empty).";
      };
    };
  };

  profileType = types.submodule {
    options = {
      _id = mkOption {
        type = types.str;
        example = "allChannels";
        description = ''
          Internal FreeTube profile identifier. The default profile
          FreeTube creates on first launch uses the id "allChannels".
        '';
      };
      name = mkOption {
        type = types.str;
        example = "All Channels";
        description = "Display name of the profile.";
      };
      bgColor = mkOption {
        type = types.str;
        default = "#BD93F9";
        description = "Background colour (hex) for the profile badge.";
      };
      textColor = mkOption {
        type = types.str;
        default = "#000000";
        description = "Text colour (hex) for the profile badge.";
      };
      subscriptions = mkOption {
        type = types.listOf subscriptionType;
        default = [];
        description = "List of channel subscriptions in this profile.";
      };
    };
  };

in
{
  # Replace the upstream HM freetube module to avoid duplicate option
  # declarations under the programs.freetube namespace.
  disabledModules = [ "programs/freetube.nix" ];

  options.programs.freetube = {
    enable = mkEnableOption "FreeTube, a privacy-respecting YouTube client";

    package = mkPackageOption pkgs "freetube" { nullable = true; };

    settings = mkOption {
      type = types.attrs;
      default = {};
      example = literalExpression ''
        {
          baseTheme           = "catppuccinMocha";
          defaultQuality      = "1080";
          backendFallback     = true;
          checkForUpdates     = false;
          allowDashAv1Formats = true;
          saveHistory         = false;
          sponsorBlockSponsor = "skip";
        }
      '';
      description = ''
        FreeTube settings written to
        {file}`$XDG_CONFIG_HOME/FreeTube/hm_settings.db` and merged into
        the live {file}`settings.db` on every activation.

        Each key/value pair becomes one NeDB record
        (`{"_id":"<key>","value":<value>}`). Discover available keys by
        changing settings in the FreeTube GUI and inspecting
        {file}`~/.config/FreeTube/settings.db`.

        Settings not listed here are left as-is in {file}`settings.db`,
        so runtime changes to other settings are preserved across rebuilds.
      '';
    };

    profiles = mkOption {
      type = types.listOf profileType;
      default = [];
      example = literalExpression ''
        [
          {
            _id   = "allChannels";
            name  = "All Channels";
            bgColor   = "#BD93F9";
            textColor = "#000000";
            subscriptions = [
              { id = "UCVls1GmFKf6WlTraIb_IaJg"; name = "DistroTube"; thumbnail = ""; }
              { id = "UC9-y-6csu5WGm29I7JiwpnA";  name = "Computerphile"; thumbnail = ""; }
            ];
          }
        ]
      '';
      description = ''
        List of FreeTube profiles written to
        {file}`$XDG_CONFIG_HOME/FreeTube/profiles.db` in NeDB format.

        This is **fully declarative**: any subscriptions added in the GUI
        will be overwritten on the next {command}`home-manager switch`.
        Add new subscriptions to this list instead.

        When empty (the default), {file}`profiles.db` is left unmanaged
        so FreeTube controls it at runtime.
      '';
    };
  };

  config = mkIf cfg.enable {

    home.packages = mkIf (cfg.package != null) [ cfg.package ];

    xdg.configFile."FreeTube/hm_settings.db" = mkIf (cfg.settings != {}) {
      text = settingsText;
    };

    xdg.configFile."FreeTube/profiles.db" = mkIf (cfg.profiles != []) {
      text = profilesText;
    };

    # Merge hm_settings.db into the live settings.db on every activation.
    # For each record: strip any existing line with the same _id, then append
    # the new line. This preserves runtime-written settings not declared here.
    home.activation.freetubeSyncSettings = lib.hm.dag.entryAfter
      [ "writeBoundary" ]
      (mkIf (cfg.settings != {}) ''
        _ft_settings="$HOME/.config/FreeTube/settings.db"
        _ft_hm="${config.xdg.configHome}/FreeTube/hm_settings.db"
        run mkdir -p "$(dirname "$_ft_settings")"
        run touch "$_ft_settings"
        while IFS= read -r _ft_line; do
          _ft_id=$(printf '%s' "$_ft_line" | grep -o '"_id":"[^"]*"' | cut -d'"' -f4)
          if [ -n "$_ft_id" ]; then
            grep -v "\"_id\":\"$_ft_id\"" "$_ft_settings" > "$_ft_settings.tmp" \
              && mv "$_ft_settings.tmp" "$_ft_settings" || true
          fi
          printf '%s\n' "$_ft_line" >> "$_ft_settings"
        done < "$_ft_hm"
        unset _ft_settings _ft_hm _ft_line _ft_id
      '');
  };
}
