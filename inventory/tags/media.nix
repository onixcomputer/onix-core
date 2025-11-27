{ pkgs, ... }:
{
  # MPD (Music Player Daemon) configuration - User service
  # Running as user service to properly access PipeWire audio
  services.mpd = {
    enable = true;
    musicDirectory = "/srv/music";
    playlistDirectory = "/srv/music/playlists";

    # Run as user service instead of system service
    # This allows proper access to user's PipeWire session
    user = "brittonr"; # Run as your user
    startWhenNeeded = false; # Start with the system

    # Network configuration
    network = {
      listenAddress = "0.0.0.0"; # Listen on all interfaces
      port = 6600;
    };

    # Extra configuration for better streaming support
    extraConfig = ''
      # Enable local socket for rmpc YouTube support
      bind_to_address "/run/mpd/socket"

      # Audio output configuration - PipeWire primary
      audio_output {
        type "pipewire"
        name "PipeWire Output"
      }

      # HTTP streaming output for network playback
      audio_output {
        type "httpd"
        name "HTTP Stream"
        encoder "lame"
        port "8000"
        bitrate "320"
        format "44100:16:2"
        always_on "yes"
        tags "yes"
      }

      # FIFO output for visualizers (cava)
      audio_output {
        type "fifo"
        name "Visualizer FIFO"
        path "/tmp/mpd.fifo"
        format "44100:16:2"
        always_on "yes"
      }

      # Database path is handled by NixOS module automatically
      # so we don't need to specify it here

      # Enable Zeroconf for automatic discovery
      zeroconf_enabled "yes"
      zeroconf_name "MPD @ %h"

      # File permissions
      filesystem_charset "UTF-8"

      # Buffer settings for network streaming
      audio_buffer_size "4096"

      # Connection settings
      max_connections "20"
      connection_timeout "60"

      # Enable volume normalization
      replaygain "album"
      volume_normalization "yes"

      # Enable HTTP/HTTPS input for streaming
      input {
        plugin "curl"
        enabled "yes"
      }
    '';
  };

  # Grant brittonr user access to audio group for MPD
  users.users.brittonr = {
    extraGroups = [ "audio" ];
  };

  # Create music directories with proper permissions
  # Since MPD runs as brittonr, directories should be accessible by that user
  systemd.tmpfiles.rules = [
    "d /srv/music 0755 brittonr audio -"
    "d /srv/music/playlists 0755 brittonr audio -"
    "d /var/lib/mpd 0755 brittonr audio -"
  ];

  # Open firewall ports for MPD and streaming
  networking.firewall.allowedTCPPorts = [
    6600 # MPD control port
    8000 # HTTP streaming port
  ];

  # Install music player clients and tools
  environment.systemPackages = with pkgs; [
    # TUI clients
    rmpc # Modern Rust-based MPD client with album art
    ncmpcpp # Feature-rich ncurses MPD client

    # CLI tools
    mpc # Command-line MPD client

    # GUI clients
    cantata # Qt-based MPD client
    vlc # Media player with UPnP/DLNA browsing support

    # Audio tools
    pulsemixer # PulseAudio/PipeWire mixer
    pavucontrol # GUI for PulseAudio/PipeWire

    # Music organization
    beets # Music library manager

    # Streaming tools
    yt-dlp # Download music from YouTube and other sources

    # Python with mutagen for rmpc YouTube support
    (python3.withPackages (
      ps: with ps; [
        mutagen # Required for rmpc's native YouTube integration
      ]
    ))

    # UPnP Media Browser Script
    (pkgs.writeScriptBin "upnp-browse" ''
      #!${pkgs.bash}/bin/bash
      # Simple UPnP/DLNA browser helper for Tidal content

      echo "🎵 UPnP Media Browser Options"
      echo "=========================="
      echo ""
      echo "Option 1: VLC Media Player"
      echo "--------------------------"
      echo "1. Open VLC"
      echo "2. Go to View → Playlist (Ctrl+L)"
      echo "3. In the left sidebar, expand 'Local Network'"
      echo "4. Click on 'Universal Plug'n'Play'"
      echo "5. You should see 'upmpdcli @ britton-desktop'"
      echo "6. Browse into it to see Tidal content"
      echo "7. Double-click any track to play through MPD"
      echo ""
      echo "Option 2: Direct MPD Control with Tidal URLs"
      echo "--------------------------------------------"
      echo "You can use rmpc to browse what's been added from Tidal:"
      echo "  rmpc"
      echo ""
      echo "Option 3: Web Browser (Experimental)"
      echo "------------------------------------"
      echo "Some UPnP renderers expose a web interface."
      echo "Try: http://localhost:49152"
      echo ""
      echo "Option 4: Command Line Discovery"
      echo "--------------------------------"
      echo "Discover UPnP devices on the network:"
      echo ""
      ${pkgs.curl}/bin/curl -s -X POST \
        -H 'Content-Type: text/xml; charset="utf-8"' \
        -H 'SOAPAction: "urn:schemas-upnp-org:service:ContentDirectory:1#Browse"' \
        -d '<?xml version="1.0" encoding="utf-8"?>
        <s:Envelope xmlns:s="http://schemas.xmlsoap.org/soap/envelope/" s:encodingStyle="http://schemas.xmlsoap.org/soap/encoding/">
          <s:Body>
            <u:Browse xmlns:u="urn:schemas-upnp-org:service:ContentDirectory:1">
              <ObjectID>0</ObjectID>
              <BrowseFlag>BrowseDirectChildren</BrowseFlag>
              <Filter>*</Filter>
              <StartingIndex>0</StartingIndex>
              <RequestedCount>10</RequestedCount>
              <SortCriteria></SortCriteria>
            </u:Browse>
          </s:Body>
        </s:Envelope>' \
        http://localhost:49152/ctl/ContentDirectory 2>/dev/null | \
        ${pkgs.gnused}/bin/sed 's/&lt;/</g; s/&gt;/>/g' | \
        ${pkgs.gnugrep}/bin/grep -o '<dc:title>[^<]*</dc:title>' | \
        ${pkgs.gnused}/bin/sed 's/<[^>]*>//g' || echo "Could not connect to UPnP service on port 49152"
      echo ""
      echo "Tip: VLC is the easiest option for browsing Tidal through upmpdcli!"
    '')

    # Tidal OAuth helper script
    (pkgs.writeScriptBin "tidal-auth" ''
            #!${pkgs.bash}/bin/bash
            # Tidal OAuth authentication helper for upmpdcli

            echo "🎵 Tidal OAuth Authentication Setup"
            echo "=================================="
            echo ""
            echo "This will trigger the Tidal OAuth flow for upmpdcli."
            echo ""
            echo "Steps:"
            echo "1. Running OAuth credential script..."
            echo "2. You will receive a link to authenticate with Tidal"
            echo "3. Open the link in your browser"
            echo "4. Log in with your Tidal account"
            echo "5. Click 'Authorize application'"
            echo ""

            # Try to run the OAuth script directly
            SCRIPT="/nix/store/z232xvgsw6mz347c0230g81n286j90xj-upmpdcli-1.9.7/share/upmpdcli/cdplugins/tidal/.tidal-app.py-wrapped"

            if [ -f "$SCRIPT" ]; then
                echo "Starting OAuth process..."
                echo "Watch for the authentication URL below:"
                echo ""
                sudo -u upmpdcli ${pkgs.python3.withPackages (ps: with ps; [ tidalapi ])}/bin/python3 -c "
      import tidalapi
      import json
      import os
      from pathlib import Path

      cache_dir = Path('/var/cache/upmpdcli/tidal')
      cache_dir.mkdir(parents=True, exist_ok=True)
      cred_file = cache_dir / 'oauth2.credentials.json'

      print('Initiating Tidal OAuth...')
      session = tidalapi.Session()

      # This will print the OAuth URL
      login = session.login_oauth()

      if login:
          print(f'\\n✅ Authentication successful!')

          # Save credentials
          creds = {
              'token_type': session.token_type,
              'access_token': session.access_token,
              'refresh_token': session.refresh_token,
              'expiry_time': session.expiry_time.timestamp() if session.expiry_time else None
          }

          with open(cred_file, 'w') as f:
              json.dump(creds, f, indent=2)

          print(f'Credentials saved to {cred_file}')
          print('\\n🎉 Tidal is now configured! Restart upmpdcli to apply:')
          print('   sudo systemctl restart upmpdcli')
      else:
          print('❌ Authentication failed. Please try again.')
      " 2>&1
            else
                echo "❌ OAuth script not found at expected location."
                echo ""
                echo "Alternative: Monitor the upmpdcli logs while accessing Tidal:"
                echo "  1. Run: sudo journalctl -u upmpdcli -f"
                echo "  2. Access Tidal through a UPnP app"
                echo "  3. Look for the OAuth URL in the logs"
            fi
    '')

    # YouTube MPD integration script
    (pkgs.writeScriptBin "mpc-yt" ''
      #!${pkgs.bash}/bin/bash
      # Add YouTube audio to MPD playlist
      # Usage: mpc-yt <youtube-url>

      URL="$1"
      if [ -z "$URL" ]; then
          echo "Usage: mpc-yt <youtube-url>"
          echo "Example: mpc-yt https://www.youtube.com/watch?v=..."
          echo ""
          echo "You can also search YouTube:"
          echo "  mpc-yt-search <search terms>"
          exit 1
      fi

      echo "🎵 Extracting audio from YouTube..."
      AUDIO_URL=$(${pkgs.yt-dlp}/bin/yt-dlp -f bestaudio --get-url "$URL" 2>/dev/null)

      if [ -z "$AUDIO_URL" ]; then
          echo "❌ Failed to extract audio URL"
          exit 1
      fi

      # Get video metadata
      TITLE=$(${pkgs.yt-dlp}/bin/yt-dlp --get-title "$URL" 2>/dev/null)
      DURATION=$(${pkgs.yt-dlp}/bin/yt-dlp --get-duration "$URL" 2>/dev/null)

      echo "📝 Adding to playlist: $TITLE ($DURATION)"
      ${pkgs.mpc}/bin/mpc add "$AUDIO_URL"

      # Start playing if not already
      if ! ${pkgs.mpc}/bin/mpc status | grep -q playing; then
          ${pkgs.mpc}/bin/mpc play
      fi

      echo "✅ Now playing via MPD!"
    '')

    # YouTube search and play script
    (pkgs.writeScriptBin "mpc-yt-search" ''
      #!${pkgs.bash}/bin/bash
      # Search YouTube and add to MPD
      # Usage: mpc-yt-search <search terms>

      SEARCH="$*"
      if [ -z "$SEARCH" ]; then
          echo "Usage: mpc-yt-search <search terms>"
          echo "Example: mpc-yt-search lofi hip hop radio"
          exit 1
      fi

      echo "🔍 Searching YouTube for: $SEARCH"
      URL=$(${pkgs.yt-dlp}/bin/yt-dlp "ytsearch:$SEARCH" --get-url --get-title | head -2)
      TITLE=$(echo "$URL" | head -1)
      VIDEO_URL=$(${pkgs.yt-dlp}/bin/yt-dlp "ytsearch:$SEARCH" --get-id | head -1)

      if [ -z "$VIDEO_URL" ]; then
          echo "❌ No results found"
          exit 1
      fi

      echo "🎵 Found: $TITLE"
      mpc-yt "https://www.youtube.com/watch?v=$VIDEO_URL"
    '')
  ];

  # Enable PipeWire for better audio handling
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
  };

  # Configure MPD systemd service to access user's PipeWire session
  systemd.services.mpd = {
    environment = {
      XDG_RUNTIME_DIR = "/run/user/1555"; # brittonr's runtime directory
    };
    serviceConfig = {
      # Use systemd-user PAM instead of login to avoid claiming a VT
      # This allows PipeWire access without blocking greetd on tty1
      PAMName = "systemd-user";
      SupplementaryGroups = [ "audio" ];
    };
  };
}
