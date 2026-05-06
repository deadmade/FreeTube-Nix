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
    mapAttrsToList
    filterAttrs
    flatten
    ;

  cfg = config.programs.freetube;

  # Strip unset (null) fields before serialising so we only write keys the
  # user actually configured.
  filteredSettings = filterAttrs (_: v: v != null) cfg.settings;
  hasSettings = filteredSettings != {};

  settingsText = concatStrings (mapAttrsToList (name: value:
    builtins.toJSON { _id = name; inherit value; } + "\n"
  ) filteredSettings);

  # Serialised as a single JSON array; the activation script resolves handles,
  # then writes the final NeDB-format profiles.db.
  profilesJson = builtins.toJSON cfg.profiles;

  # ---------------------------------------------------------------------------
  # Sub-types
  # ---------------------------------------------------------------------------

  sponsorBlockActionType = types.enum [
    "skip" "mute" "autoSkip" "doNothing" "showIcon"
  ];

  boundsType = types.submodule {
    options = {
      x         = mkOption { type = types.int;  default = 0;    description = "Window x position."; };
      y         = mkOption { type = types.int;  default = 0;    description = "Window y position."; };
      width     = mkOption { type = types.int;  default = 1280; description = "Window width in pixels."; };
      height    = mkOption { type = types.int;  default = 720;  description = "Window height in pixels."; };
      maximized  = mkOption { type = types.bool; default = false; description = "Start maximized."; };
      fullScreen = mkOption { type = types.bool; default = false; description = "Start in full-screen mode."; };
    };
  };

  subscriptionType = types.submodule {
    options = {
      id = mkOption {
        type    = types.nullOr types.str;
        default = null;
        description = ''
          YouTube channel ID (e.g. "UCfEkarF_pUayXFVWHHsm11w").
          Either this or {option}`handle` must be set.
        '';
      };
      handle = mkOption {
        type    = types.nullOr types.str;
        default = null;
        example = "@CalcioBerlin";
        description = ''
          YouTube channel handle (e.g. "@CalcioBerlin"). When set and
          {option}`id` is null, the activation script queries
          {option}`programs.freetube.invidiousInstance` to resolve the
          channel ID automatically and caches the result in
          {file}`~/.config/FreeTube/channel_ids.lock.json`.
        '';
      };
      name = mkOption {
        type = types.str;
        description = "Human-readable channel name.";
      };
      thumbnail = mkOption {
        type    = types.str;
        default = "";
        description = "URL to the channel thumbnail (leave empty to let FreeTube fetch it).";
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

  # ---------------------------------------------------------------------------
  # Typed settings submodule — every option is nullOr so that unset options
  # are simply omitted from the generated settings.db lines.
  # ---------------------------------------------------------------------------
  settingsType = types.submodule {
    options = {

      # -- Video / Playback ---------------------------------------------------
      allowDashAv1Formats = mkOption {
        type    = types.nullOr types.bool;
        default = null;
        description = "Allow DASH AV1 video formats.";
      };
      defaultQuality = mkOption {
        type    = types.nullOr (types.enum [ "144" "240" "360" "480" "720" "1080" "1440" "2160" "4320" "auto" ]);
        default = null;
        description = "Default video quality.";
      };
      playNextVideo = mkOption {
        type    = types.nullOr types.bool;
        default = null;
        description = "Automatically play the next video in the list.";
      };
      thumbnailPreference = mkOption {
        type    = types.nullOr (types.enum [ "default" "start" "end" ]);
        default = null;
        description = "Which thumbnail frame to display.";
      };
      blurThumbnails = mkOption {
        type    = types.nullOr types.bool;
        default = null;
        description = "Blur video thumbnails.";
      };

      # -- Backend ------------------------------------------------------------
      backendPreference = mkOption {
        type    = types.nullOr (types.enum [ "local" "invidious" ]);
        default = null;
        description = "Preferred backend for fetching video data.";
      };
      backendFallback = mkOption {
        type    = types.nullOr types.bool;
        default = null;
        description = "Fall back to the other backend on failure.";
      };

      # -- Appearance ---------------------------------------------------------
      baseTheme = mkOption {
        type = types.nullOr (types.enum [
          "dark" "light" "black" "dracula"
          "catppuccinMocha" "catppuccinMacchiato" "catppuccinFrappe" "catppuccinLatte"
          "hotPink" "pastelPink" "nordic" "solarizedDark" "solarizedLight"
        ]);
        default = null;
        description = "UI colour theme.";
      };
      listType = mkOption {
        type    = types.nullOr (types.enum [ "list" "grid" ]);
        default = null;
        description = "Video list display style.";
      };
      currentLocale = mkOption {
        type    = types.nullOr (types.strMatching "[a-z]{2}(-[A-Z]{2})?");
        default = null;
        example = "de-DE";
        description = ''
          UI locale code. Must be in the form "xx" or "xx-XX"
          (e.g. "en", "de-DE", "zh-CN").
        '';
      };
      landingPage = mkOption {
        type = types.nullOr (types.enum [
          "subscriptions" "subscribedchannels" "trending" "popular"
          "playlists" "history" "settings"
        ]);
        default = null;
        description = "Page shown on launch.";
      };
      bounds = mkOption {
        type    = types.nullOr boundsType;
        default = null;
        description = "Initial window geometry and state.";
      };
      settingsSectionSortEnabled = mkOption {
        type    = types.nullOr types.bool;
        default = null;
        description = "Sort settings sections alphabetically.";
      };

      # -- Privacy / History --------------------------------------------------
      saveHistory = mkOption {
        type    = types.nullOr types.bool;
        default = null;
        description = "Save watch history locally.";
      };
      checkForUpdates = mkOption {
        type    = types.nullOr types.bool;
        default = null;
        description = "Check for FreeTube updates on startup.";
      };
      useRssFeeds = mkOption {
        type    = types.nullOr types.bool;
        default = null;
        description = "Use RSS feeds to fetch subscription updates.";
      };
      region = mkOption {
        type    = types.nullOr (types.strMatching "[A-Z]{2}");
        default = null;
        example = "US";
        description = ''
          Two-letter ISO 3166-1 alpha-2 region code used for recommendations
          (e.g. "US", "DE", "UG").
        '';
      };

      # -- SponsorBlock -------------------------------------------------------
      useSponsorBlock = mkOption {
        type    = types.nullOr types.bool;
        default = null;
        description = "Enable SponsorBlock segment skipping.";
      };
      sponsorBlockSponsor = mkOption {
        type    = types.nullOr sponsorBlockActionType;
        default = null;
        description = "Action for sponsor segments.";
      };
      sponsorBlockSelfPromo = mkOption {
        type    = types.nullOr sponsorBlockActionType;
        default = null;
        description = "Action for self-promotion segments.";
      };
      sponsorBlockInteraction = mkOption {
        type    = types.nullOr sponsorBlockActionType;
        default = null;
        description = "Action for interaction reminder segments.";
      };
      sponsorBlockIntro = mkOption {
        type    = types.nullOr sponsorBlockActionType;
        default = null;
        description = "Action for intro segments.";
      };
      sponsorBlockOutro = mkOption {
        type    = types.nullOr sponsorBlockActionType;
        default = null;
        description = "Action for outro segments.";
      };
      sponsorBlockPreview = mkOption {
        type    = types.nullOr sponsorBlockActionType;
        default = null;
        description = "Action for preview/recap segments.";
      };
      sponsorBlockMusicOffTopic = mkOption {
        type    = types.nullOr sponsorBlockActionType;
        default = null;
        description = "Action for music off-topic segments.";
      };

      # -- DeArrow ------------------------------------------------------------
      useDeArrowTitles = mkOption {
        type    = types.nullOr types.bool;
        default = null;
        description = "Replace titles with DeArrow community-sourced titles.";
      };
      useDeArrowThumbnails = mkOption {
        type    = types.nullOr types.bool;
        default = null;
        description = "Replace thumbnails with DeArrow community-sourced thumbnails.";
      };

      # -- Hide / Distraction-free --------------------------------------------
      hideVideoViews = mkOption {
        type    = types.nullOr types.bool;
        default = null;
        description = "Hide video view counts.";
      };
      hideChannelSubscriptions = mkOption {
        type    = types.nullOr types.bool;
        default = null;
        description = "Hide channel subscription counts.";
      };
      hideSharingActions = mkOption {
        type    = types.nullOr types.bool;
        default = null;
        description = "Hide sharing action buttons.";
      };
      hideWatchedSubs = mkOption {
        type    = types.nullOr types.bool;
        default = null;
        description = "Hide already-watched videos in the subscriptions feed.";
      };
      hideLiveStreams = mkOption {
        type    = types.nullOr types.bool;
        default = null;
        description = "Hide live streams from feeds.";
      };
      hideUpcomingPremieres = mkOption {
        type    = types.nullOr types.bool;
        default = null;
        description = "Hide upcoming premieres from feeds.";
      };
      showDistractionFreeTitles = mkOption {
        type    = types.nullOr types.bool;
        default = null;
        description = "Show distraction-free video titles.";
      };
      hideTrendingVideos = mkOption {
        type    = types.nullOr types.bool;
        default = null;
        description = "Hide the trending videos section.";
      };
      hidePopularVideos = mkOption {
        type    = types.nullOr types.bool;
        default = null;
        description = "Hide the popular videos section.";
      };
      hidePlaylists = mkOption {
        type    = types.nullOr types.bool;
        default = null;
        description = "Hide playlists.";
      };
      hideActiveSubscriptions = mkOption {
        type    = types.nullOr types.bool;
        default = null;
        description = "Hide the active subscriptions sidebar widget.";
      };
      hideSubscriptionsVideos = mkOption {
        type    = types.nullOr types.bool;
        default = null;
        description = "Hide the Videos tab in subscriptions.";
      };
      hideSubscriptionsShorts = mkOption {
        type    = types.nullOr types.bool;
        default = null;
        description = "Hide the Shorts tab in subscriptions.";
      };
      hideSubscriptionsCommunity = mkOption {
        type    = types.nullOr types.bool;
        default = null;
        description = "Hide the Community tab in subscriptions.";
      };
      hideChannelHome = mkOption {
        type    = types.nullOr types.bool;
        default = null;
        description = "Hide the Home tab on channel pages.";
      };
      hideChannelShorts = mkOption {
        type    = types.nullOr types.bool;
        default = null;
        description = "Hide the Shorts tab on channel pages.";
      };
      hideChannelPlaylists = mkOption {
        type    = types.nullOr types.bool;
        default = null;
        description = "Hide the Playlists tab on channel pages.";
      };
      hideChannelPodcasts = mkOption {
        type    = types.nullOr types.bool;
        default = null;
        description = "Hide the Podcasts tab on channel pages.";
      };
      hideChannelCourses = mkOption {
        type    = types.nullOr types.bool;
        default = null;
        description = "Hide the Courses tab on channel pages.";
      };
      hideChannelReleases = mkOption {
        type    = types.nullOr types.bool;
        default = null;
        description = "Hide the Releases tab on channel pages.";
      };
      hideChannelCommunity = mkOption {
        type    = types.nullOr types.bool;
        default = null;
        description = "Hide the Community tab on channel pages.";
      };
      hideFeaturedChannels = mkOption {
        type    = types.nullOr types.bool;
        default = null;
        description = "Hide featured/recommended channels.";
      };
      hideVideoLikesAndDislikes = mkOption {
        type    = types.nullOr types.bool;
        default = null;
        description = "Hide like and dislike counts on videos.";
      };
      hideChapters = mkOption {
        type    = types.nullOr types.bool;
        default = null;
        description = "Hide video chapters.";
      };
      hideVideoDescription = mkOption {
        type    = types.nullOr types.bool;
        default = null;
        description = "Hide video descriptions.";
      };
      hideCommentLikes = mkOption {
        type    = types.nullOr types.bool;
        default = null;
        description = "Hide like counts on comments.";
      };
      hideCommentPhotos = mkOption {
        type    = types.nullOr types.bool;
        default = null;
        description = "Hide commenter profile photos.";
      };
      hideComments = mkOption {
        type    = types.nullOr types.bool;
        default = null;
        description = "Hide the comments section entirely.";
      };
      hideRecommendedVideos = mkOption {
        type    = types.nullOr types.bool;
        default = null;
        description = "Hide the recommended videos sidebar.";
      };
      hideLiveChat = mkOption {
        type    = types.nullOr types.bool;
        default = null;
        description = "Hide live chat on live streams.";
      };

      # -- Behaviour ----------------------------------------------------------
      generalAutoLoadMorePaginatedItemsEnabled = mkOption {
        type    = types.nullOr types.bool;
        default = null;
        description = "Automatically load more items in paginated lists.";
      };
      openDeepLinksInNewWindow = mkOption {
        type    = types.nullOr types.bool;
        default = null;
        description = "Open YouTube deep links in a new FreeTube window.";
      };
      hideToTrayOnMinimize = mkOption {
        type    = types.nullOr types.bool;
        default = null;
        description = "Minimise to the system tray instead of the taskbar.";
      };
      unsubscriptionPopupStatus = mkOption {
        type    = types.nullOr types.bool;
        default = null;
        description = "Show a confirmation popup before unsubscribing from a channel.";
      };
      onlyShowLatestFromChannel = mkOption {
        type    = types.nullOr types.bool;
        default = null;
        description = "Only show the latest N videos per channel in the subscription feed.";
      };
      onlyShowLatestFromChannelNumber = mkOption {
        type    = types.nullOr types.ints.positive;
        default = null;
        description = ''
          Number of latest videos per channel to show when
          {option}`onlyShowLatestFromChannel` is enabled.
        '';
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

    invidiousInstance = mkOption {
      type    = types.str;
      default = "https://inv.nadeko.net";
      example = "https://invidious.example.com";
      description = ''
        Invidious instance base URL used by the activation script to resolve
        channel handles to YouTube channel IDs.

        The resolved IDs are cached in
        {file}`~/.config/FreeTube/channel_ids.lock.json`; delete that file
        to force a fresh lookup (e.g. after changing instance).
      '';
    };

    settings = mkOption {
      type = settingsType;
      default = {};
      example = literalExpression ''
        {
          baseTheme           = "catppuccinMocha";
          defaultQuality      = "1080";
          backendPreference   = "invidious";
          backendFallback     = true;
          checkForUpdates     = false;
          saveHistory         = false;
          useSponsorBlock     = true;
          sponsorBlockSponsor = "skip";
          useDeArrowTitles    = true;
          currentLocale       = "de-DE";
          region              = "UG";
          landingPage         = "subscribedchannels";
          bounds = {
            x = 0; y = 0; width = 960; height = 1050;
            maximized = true; fullScreen = false;
          };
        }
      '';
      description = ''
        FreeTube settings written to
        {file}`$XDG_CONFIG_HOME/FreeTube/hm_settings.db` and merged into
        the live {file}`settings.db` on every activation.

        Each non-null option becomes one NeDB record
        (`{"_id":"<key>","value":<value>}`). Options left at their default
        of `null` are omitted and therefore left untouched in
        {file}`settings.db`, so runtime changes to those settings are
        preserved across rebuilds.
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

    assertions = flatten (map (profile:
      map (sub: {
        assertion = sub.id != null || sub.handle != null;
        message = ''
          programs.freetube: subscription "${sub.name}" in profile "${profile.name}" \
          must have either `id` or `handle` set.
        '';
      }) profile.subscriptions
    ) cfg.profiles);

    home.packages = mkIf (cfg.package != null) [ cfg.package ];

    xdg.configFile."FreeTube/hm_settings.db" = mkIf hasSettings {
      text = settingsText;
    };

    # Raw JSON written to the Nix store; the activation script processes it into
    # the mutable NeDB profiles.db (resolving handles along the way).
    xdg.configFile."FreeTube/hm_profiles_raw.json" = mkIf (cfg.profiles != []) {
      text = profilesJson;
    };

    # Resolve channel handles → IDs via Invidious, then write profiles.db.
    # IDs are cached in channel_ids.lock.json so each handle is only fetched once.
    home.activation.freetubeSyncProfiles = lib.hm.dag.entryAfter
      [ "writeBoundary" ]
      (mkIf (cfg.profiles != []) ''
        _ft_raw="${config.xdg.configHome}/FreeTube/hm_profiles_raw.json"
        _ft_cache="$HOME/.config/FreeTube/channel_ids.lock.json"
        _ft_profiles="$HOME/.config/FreeTube/profiles.db"
        _ft_invidious="${cfg.invidiousInstance}"

        run mkdir -p "$(dirname "$_ft_profiles")"
        [ -f "$_ft_cache" ] || echo '{}' > "$_ft_cache"

        # Resolve any handle not yet in the cache.
        # Attempt 1: /channels/<handle> (fast, supported on most instances).
        # Attempt 2: /search?q=<handle>&type=channel (universal fallback).
        for _ft_handle in $(${pkgs.jq}/bin/jq -r \
            '[.[].subscriptions[] | select(.id == null and .handle != null) | .handle] | unique[]' \
            "$_ft_raw"); do
          if ! ${pkgs.jq}/bin/jq -e --arg h "$_ft_handle" 'has($h)' "$_ft_cache" > /dev/null 2>&1; then
            echo "freetube: resolving $_ft_handle via $_ft_invidious" >&2
            _ft_id=""

            _ft_id=$(${pkgs.curl}/bin/curl -s --max-time 10 \
                "$_ft_invidious/api/v1/channels/$_ft_handle" \
              | ${pkgs.jq}/bin/jq -r '(.authorId // .ucid) // empty' 2>/dev/null || true)

            if [ -z "$_ft_id" ]; then
              _ft_id=$(${pkgs.curl}/bin/curl -s --max-time 10 \
                  --get \
                  --data-urlencode "q=$_ft_handle" \
                  --data-urlencode "type=channel" \
                  "$_ft_invidious/api/v1/search" \
                | ${pkgs.jq}/bin/jq -r \
                  '[.[] | select(.type == "channel")] | .[0].authorId // empty' \
                  2>/dev/null || true)
            fi

            if [ -n "$_ft_id" ]; then
              echo "freetube: $_ft_handle → $_ft_id" >&2
              ${pkgs.jq}/bin/jq --arg h "$_ft_handle" --arg id "$_ft_id" \
                '.[$h] = $id' "$_ft_cache" > "$_ft_cache.tmp" \
                && mv "$_ft_cache.tmp" "$_ft_cache"
            else
              echo "freetube: warning: could not resolve $_ft_handle" >&2
              echo "freetube: check that $_ft_invidious is reachable, or set programs.freetube.invidiousInstance to a different instance" >&2
            fi
          fi
        done

        # Emit one compact JSON object per profile (NeDB format)
        ${pkgs.jq}/bin/jq -c \
          --argjson cache "$(cat "$_ft_cache")" \
          '.[] | {
            _id,
            name,
            bgColor,
            textColor,
            subscriptions: [
              .subscriptions[] |
              if (.id == null and .handle != null) then
                . + { id: ($cache[.handle] // null) }
              else . end |
              del(.handle) |
              select(.id != null)
            ]
          }' "$_ft_raw" > "$_ft_profiles"

        unset _ft_raw _ft_cache _ft_profiles _ft_invidious _ft_handle _ft_id
      '');

    # Merge hm_settings.db into the live settings.db on every activation.
    # For each record: strip any existing line with the same _id, then append
    # the new line. This preserves runtime-written settings not declared here.
    home.activation.freetubeSyncSettings = lib.hm.dag.entryAfter
      [ "writeBoundary" ]
      (mkIf hasSettings ''
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
