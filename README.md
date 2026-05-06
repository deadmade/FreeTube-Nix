# freetube-nix

A Home Manager module for declarative [FreeTube](https://freetubeapp.io/) configuration with full profile and subscription support.

## Features

- Typed, validated settings — invalid values are caught at `home-manager switch` time
- Selective merging: only settings you declare are written; everything else in `settings.db` is preserved
- Fully declarative profile and subscription management

## Installation

Add this flake as an input and import the module:

```nix
# flake.nix
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    freetube-nix = {
      url = "github:deadmade/FreeTube-Nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { nixpkgs, home-manager, freetube-nix, ... }: {
    homeConfigurations."youruser" = home-manager.lib.homeManagerConfiguration {
      modules = [
        freetube-nix.homeManagerModules.default
        ./home.nix
      ];
    };
  };
}
```

## Usage

```nix
# home.nix
programs.freetube = {
  enable = true;

  settings = {
    baseTheme    = "catppuccinMocha";
    defaultQuality = "1080";
    saveHistory  = false;
  };
};
```

Options left at their default of `null` are not written to `settings.db`, so FreeTube's own runtime changes to those settings are preserved across rebuilds.

---

## `programs.freetube.settings` reference

All options are `null` by default (unset / not managed).

### Video / Playback

```nix
programs.freetube.settings = {
  # Allow DASH AV1 video formats.
  allowDashAv1Formats = true; # bool

  # Default video quality.
  # "144" | "240" | "360" | "480" | "720" | "1080" | "1440" | "2160" | "4320" | "auto"
  defaultQuality = "1080";

  # Automatically play the next video in the list.
  playNextVideo = false; # bool

  # Which thumbnail frame to display.
  # "default" | "start" | "end"
  thumbnailPreference = "start";

  # Blur video thumbnails.
  blurThumbnails = false; # bool
};
```

### Backend

```nix
programs.freetube.settings = {
  # Preferred backend for fetching video data.
  # "local" | "invidious"
  backendPreference = "invidious";

  # Fall back to the other backend on failure.
  backendFallback = true; # bool
};
```

### Appearance

```nix
programs.freetube.settings = {
  # UI colour theme.
  # "dark" | "light" | "black" | "dracula"
  # | "catppuccinMocha" | "catppuccinMacchiato" | "catppuccinFrappe" | "catppuccinLatte"
  # | "hotPink" | "pastelPink" | "nordic" | "solarizedDark" | "solarizedLight"
  baseTheme = "catppuccinMocha";

  # Video list display style.
  # "list" | "grid"
  listType = "list";

  # UI locale. Format: "xx" or "xx-XX" (e.g. "en", "de-DE", "zh-CN").
  currentLocale = "de-DE";

  # Page shown on launch.
  # "subscriptions" | "subscribedchannels" | "trending" | "popular"
  # | "playlists" | "history" | "settings"
  landingPage = "subscribedchannels";

  # Sort settings sections alphabetically.
  settingsSectionSortEnabled = true; # bool

  # Initial window geometry and state.
  bounds = {
    x          = 0;     # int — window x position
    y          = 0;     # int — window y position
    width      = 960;   # int — window width in pixels
    height     = 1050;  # int — window height in pixels
    maximized  = true;  # bool
    fullScreen = false; # bool
  };
};
```

### Privacy / History

```nix
programs.freetube.settings = {
  # Save watch history locally.
  saveHistory = false; # bool

  # Check for FreeTube updates on startup.
  checkForUpdates = false; # bool

  # Use RSS feeds to fetch subscription updates.
  useRssFeeds = true; # bool

  # Two-letter ISO 3166-1 alpha-2 region code (e.g. "US", "DE", "UG").
  region = "UG";
};
```

### SponsorBlock

All segment actions accept: `"skip"` | `"mute"` | `"autoSkip"` | `"doNothing"` | `"showIcon"`

```nix
programs.freetube.settings = {
  # Enable SponsorBlock segment skipping.
  useSponsorBlock = true; # bool

  sponsorBlockSponsor      = "skip";
  sponsorBlockSelfPromo    = "skip";
  sponsorBlockInteraction  = "skip";
  sponsorBlockIntro        = "skip";
  sponsorBlockOutro        = "skip";
  sponsorBlockPreview      = "skip";
  sponsorBlockMusicOffTopic = "skip";
};
```

### DeArrow

```nix
programs.freetube.settings = {
  # Replace titles with DeArrow community-sourced titles.
  useDeArrowTitles = true; # bool

  # Replace thumbnails with DeArrow community-sourced thumbnails.
  useDeArrowThumbnails = false; # bool
};
```

### Hide / Distraction-free

```nix
programs.freetube.settings = {
  # General
  hideVideoViews             = true;  # bool — hide video view counts
  hideChannelSubscriptions   = true;  # bool — hide channel sub counts
  hideSharingActions         = true;  # bool — hide share buttons
  showDistractionFreeTitles  = true;  # bool — show distraction-free titles
  hideTrendingVideos         = true;  # bool
  hidePopularVideos          = true;  # bool
  hidePlaylists              = true;  # bool
  hideFeaturedChannels       = true;  # bool

  # Subscription feed
  hideWatchedSubs            = true;  # bool — hide already-watched videos
  hideLiveStreams             = true;  # bool
  hideUpcomingPremieres      = true;  # bool
  hideActiveSubscriptions    = true;  # bool — hide sidebar widget
  hideSubscriptionsVideos    = true;  # bool — hide Videos tab
  hideSubscriptionsShorts    = true;  # bool — hide Shorts tab
  hideSubscriptionsCommunity = true;  # bool — hide Community tab

  # Channel pages
  hideChannelHome            = true;  # bool
  hideChannelShorts          = true;  # bool
  hideChannelPlaylists       = true;  # bool
  hideChannelPodcasts        = true;  # bool
  hideChannelCourses         = true;  # bool
  hideChannelReleases        = true;  # bool
  hideChannelCommunity       = true;  # bool

  # Video page
  hideVideoLikesAndDislikes  = true;  # bool
  hideChapters               = true;  # bool
  hideVideoDescription       = true;  # bool
  hideRecommendedVideos      = true;  # bool
  hideLiveChat               = true;  # bool

  # Comments
  hideComments               = true;  # bool
  hideCommentLikes           = true;  # bool
  hideCommentPhotos          = true;  # bool
};
```

### Behaviour

```nix
programs.freetube.settings = {
  # Automatically load more items in paginated lists.
  generalAutoLoadMorePaginatedItemsEnabled = true; # bool

  # Open YouTube deep links in a new FreeTube window.
  openDeepLinksInNewWindow = true; # bool

  # Minimise to the system tray instead of the taskbar.
  hideToTrayOnMinimize = true; # bool

  # Show a confirmation popup before unsubscribing from a channel.
  unsubscriptionPopupStatus = true; # bool

  # Only show the latest N videos per channel in the subscription feed.
  onlyShowLatestFromChannel = true; # bool

  # How many latest videos per channel to show (requires onlyShowLatestFromChannel).
  # Must be a positive integer.
  onlyShowLatestFromChannelNumber = 16;
};
```

---

## `programs.freetube.profiles` reference

Profiles are **fully declarative**: on every `home-manager switch` the module resolves any channel handles, then writes the final `profiles.db`. Leave `profiles` at `[]` (the default) to let FreeTube manage subscriptions at runtime.

### Automatic handle resolution

Set `handle` instead of `id` and the activation script will query the configured Invidious instance to look up the channel ID automatically. Resolved IDs are cached in `~/.config/FreeTube/channel_ids.lock.json` so each handle is only fetched once. Delete that file to force a fresh lookup.

```nix
# Optional: override the Invidious instance used for handle resolution
programs.freetube.invidiousInstance = "https://inv.nadeko.net";

programs.freetube.profiles = [
  {
    _id       = "allChannels"; # internal FreeTube ID; the built-in profile uses "allChannels"
    name      = "All Channels";
    bgColor   = "#BD93F9";     # hex background colour for the profile badge
    textColor = "#000000";     # hex text colour for the profile badge
    subscriptions = [
      # Provide a handle — ID is resolved automatically at switch time
      { handle = "@DistroTube";    name = "DistroTube"; }
      { handle = "@Computerphile"; name = "Computerphile"; }

      # Or supply the channel ID directly (no network call needed)
      {
        id        = "UCVls1GmFKf6WlTraIb_IaJg";
        name      = "DistroTube";
        thumbnail = ""; # optional — FreeTube fetches it if left empty
      }
    ];
  }
];
```

Each subscription must have either `id` or `handle` set — omitting both is a Nix evaluation error.
