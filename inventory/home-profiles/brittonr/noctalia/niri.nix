{
  inputs,
  pkgs,
  lib,
  config,
  ...
}:
let
  # Access the current theme colors
  theme = config.theme.colors;
  mon = config.monitors;

  # Import niri keybindings from separate file
  niriBinds = import ./lib/niri-keybinds.nix { inherit config pkgs lib; };

  # Use niri from our fork
  niriPackage = inputs.niri.packages.${pkgs.stdenv.hostPlatform.system}.niri;

  # Animated harmonograph wallpaper
  wl-harmonograph = inputs.wl-harmonograph.packages.${pkgs.stdenv.hostPlatform.system}.default;

  # ── Niri config content ────────────────────────────────────────────────
  # Generated at build time, copied to ~/.config/niri/config.kdl by the
  # activation script so it's mutable at runtime. Noctalia's template
  # processor writes noctalia.kdl alongside it; the include at the bottom
  # overrides the hardcoded colour defaults with the live palette.
  niriConfigContent = /* kdl */ ''
                              // Niri configuration with Noctalia Shell integration
                              // Noctalia provides: bar, notifications, launcher, OSD, wallpaper, lock screen

                              input {
                                  keyboard {
                                      xkb {
                                          layout "${config.input.keyboard.layout}"
                                      }
                                  }

                                  touchpad {
                                      ${if config.input.touchpad.tap then "tap" else ""}
                                      ${
                                        if config.input.touchpad.naturalScroll then "natural-scroll" else ""
                                      }
                                      ${
                                        if config.input.touchpad.disableWhileTyping then
                                          ''
                                            dwt  // disable while typing
                                            dwtp // disable while trackpointing''
                                        else
                                          ""
                                      }
                                      drag true
                                      drag-lock
                                      click-method "${config.input.touchpad.clickMethod}"
                                      scroll-method "${config.input.touchpad.scrollMethod}"
                                      accel-speed ${toString config.input.touchpad.accelSpeed}
                                      accel-profile "${config.input.touchpad.accelProfile}"
                                  }

                                  // Touchscreen settings for GPD Pocket 4
                                  touch {
                                      map-to-output "${mon.builtin.name}"
                                  }

                                  // Tablet/stylus settings (if applicable)
                                  tablet {
                                      map-to-output "${mon.builtin.name}"
                                  }

                                  ${
                                    if config.input.mouse.focusFollows then "focus-follows-mouse" else ""
                                  }
                                  ${
                                    if config.input.mouse.warpToFocus then "warp-mouse-to-focus" else ""
                                  }
                              }

                              // Gesture configuration for touchpad and touchscreen
                              gestures {
                                  // Scroll the view when dragging near monitor edges
                                  dnd-edge-view-scroll {
                                      trigger-width ${toString config.gestures.dndEdgeScroll.triggerWidth}
                                      delay-ms ${toString config.gestures.dndEdgeScroll.delayMs}
                                      max-speed ${toString config.gestures.dndEdgeScroll.maxSpeed}
                                  }

                                  // Enable hot corner to toggle overview (top-left)
                                  hot-corners {
                                      top-left
                                  }
                              }

                              // Force AMD iGPU as render device for outputs without their own
                              // render node (DisplayLink/evdi). NVIDIA's GBM allocator doesn't
                              // export linear dmabufs in formats evdi accepts. AMD's amdgpu does.
                              // NVIDIA outputs (DP-3) still use their own renderD129.
                              debug {
                                  render-drm-device "/dev/dri/renderD128"
                              }

                              // Primary monitor (top) - LG ULTRAGEAR+
                              output "${mon.primary.name}" {
                                  ${
                                    if mon.primary.mode != "preferred" then ''mode "${mon.primary.mode}"'' else ""
                                  }
                                  scale ${toString mon.primary.scale}
                                  position x=${toString mon.primary.position.x} y=${toString mon.primary.position.y}
                                  ${if mon.primary.vrr then "variable-refresh-rate" else ""}
                              }

                              // Secondary monitor (below, centered) - Portable monitor via HDMI
                              output "${mon.secondary.name}" {
                                  ${
                                    if mon.secondary.mode != "preferred" then ''mode "${mon.secondary.mode}"'' else ""
                                  }
                                  scale ${toString mon.secondary.scale}
                                  position x=${toString mon.secondary.position.x} y=${toString mon.secondary.position.y}
                              }

                              // Elgato Prompter (DisplayLink/evdi via USB)
                              output "DVI-I-1" {
                                  mode "1024x600@60"
                                  scale 1
                              }


                              prefer-no-csd

                              overview {
                                  workspace-gap 0.0
                              }

                              layout {
                                  empty-workspace-above-first
                                  gaps ${toString config.layout.gaps}
                                  center-focused-column "never"
                                  focus-column-tile "spatial"
                                  preset-column-widths {
                                      ${builtins.concatStringsSep "\n                                  "
                                        (map (w: "proportion ${toString w}") config.layout.presetColumnWidths)
                                      }
                                  }

                                  focus-ring {
                                      active-color "${theme.accent}"
                                      inactive-color "${theme.border}"
                                      width ${toString config.layout.focusRingWidth}
                                  }

                                  border {
                                      width ${toString config.layout.borderWidth}
                                      active-color "${theme.accent}"
                                      inactive-color "${theme.border}"
                                  }
                              }

                              ${builtins.concatStringsSep "\n                          " (
                                map (name: "workspace \"${name}\"") config.workspaces.names
                              )}

                              // Startup services - Noctalia replaces waybar, swayosd, swww, mako
                              spawn-at-startup "noctalia-shell"
                              spawn-at-startup "${wl-harmonograph}/bin/wl-harmonograph"
                              spawn-at-startup "${pkgs.wl-clipboard}/bin/wl-paste" "--watch" "${pkgs.cliphist}/bin/cliphist" "store"
                              spawn-at-startup "${pkgs.polkit_gnome}/libexec/polkit-gnome-authentication-agent-1"
                              spawn-at-startup "${pkgs.networkmanagerapplet}/bin/nm-applet"
                              spawn-at-startup "${pkgs.blueman}/bin/blueman-applet"

                              // Startup applications
                              spawn-at-startup "vesktop" "--enable-features=UseOzonePlatform" "--ozone-platform=wayland" "--enable-wayland-ime" "--disable-gpu-sandbox"
                              spawn-at-startup "element-desktop"
                              spawn-at-startup "${config.apps.terminal.command}" "--title" "${config.apps.sysmon.name}" "-e" "${config.apps.sysmon.command}"
                              spawn-at-startup "${config.apps.terminal.command}" "--title" "journalctl" "-e" "${pkgs.systemd}/bin/journalctl -f"

                              // Window rules: workspace assignments
                              ${builtins.concatStringsSep "\n                          " (
                                map (rule: ''
                                  window-rule {
                                      match app-id=r#"${rule.appId}$"#
                                      open-on-workspace "${rule.workspace}"
                                      ${if rule ? maximized && rule.maximized then "open-maximized true" else ""}
                                  }'') config.windowRules.assignments
                              )}

                              // Window rules: title-specific overrides
                              ${builtins.concatStringsSep "\n                          " (
                                map (rule: ''
                                  window-rule {
                                      match app-id=r#"${rule.appId}$"# title="${rule.title}"
                                      ${if rule ? workspace then ''open-on-workspace "${rule.workspace}"'' else ""}
                                      ${if rule ? maximized && rule.maximized then "open-maximized true" else ""}
                                      ${if rule ? floating && rule.floating then "open-floating true" else ""}
                                  }'') config.windowRules.titleOverrides
                              )}

                              window-rule {
                  match app-id=r#"${config.apps.terminal.appId}$"# title="^${config.apps.fileManager.name}$"
              }

              // Indicate screencasted windows with red colors.
              window-rule {
                  match is-window-cast-target=true

                  focus-ring {
                      active-color "${config.colors.screencast_active}"
                      inactive-color "${config.colors.screencast_inactive}"
                  }

                  border {
                      inactive-color "${config.colors.screencast_inactive}"
                  }

                  shadow {
                      color "${config.colors.screencast_inactive}${config.opacity.hex.low}"
                  }

                  tab-indicator {
                      active-color "${config.colors.screencast_active}"
                      inactive-color "${config.colors.screencast_inactive}"
                  }
              }

              xwayland-satellite {
                  // off
                  path "xwayland-satellite"
              }

    ${niriBinds}

    // ── Noctalia live theme integration ──────────────────────────
    // noctalia.kdl is generated by the Noctalia template processor
    // whenever the colour scheme changes (wallpaper, dark/light
    // toggle, manual scheme pick). Its layout block merges with
    // the one above — later values win — so only colours are
    // overridden while gaps/widths/presets are preserved.
    include "./noctalia.kdl"
  '';

  # Store the config as a derivation for the activation script to copy
  niriConfigFile = pkgs.writeText "niri-config.kdl" niriConfigContent;

  # Initial noctalia.kdl seeded from the Nix theme so niri never starts
  # with a missing include. Noctalia's template processor overwrites this
  # the first time it runs.
  initialNoctaliaKdl = pkgs.writeText "noctalia-initial.kdl" ''
    layout {
        focus-ring {
            active-color   "${theme.accent}"
            inactive-color "${theme.border}"
            urgent-color   "${theme.red}"
        }
        border {
            active-color   "${theme.accent}"
            inactive-color "${theme.border}"
            urgent-color   "${theme.red}"
        }
        shadow {
            color "${theme.bg_dark}70"
        }
        tab-indicator {
            active-color   "${theme.accent}"
            inactive-color "${theme.bg_highlight}"
            urgent-color   "${theme.red}"
        }
        insert-hint {
            color "${theme.accent}80"
        }
    }

    recent-windows {
        highlight {
            active-color "${theme.accent}"
            urgent-color "${theme.red}"
        }
    }
  '';

  # Validate the config at build time (without the include, since
  # noctalia.kdl doesn't exist in the store).
  niriConfigValidated = pkgs.runCommand "niri-config-validate" { } ''
    dir=$(mktemp -d)
    cp ${niriConfigFile} "$dir/config.kdl"
    touch "$dir/noctalia.kdl"
    ${lib.getExe niriPackage} validate -c "$dir/config.kdl"
    touch $out
  '';

  # ── Wrapped niri binary ────────────────────────────────────────────────
  # Points NIRI_CONFIG at the mutable XDG path instead of the nix store.
  # $HOME is expanded at runtime by the wrapper shell script.
  wrappedNiri =
    (inputs.wrappers.wrapperModules.niri.apply {
      inherit pkgs;
      package = lib.mkForce niriPackage;

      "config.kdl".path = "\${XDG_CONFIG_HOME:-$HOME/.config}/niri/config.kdl";
    }).wrapper;
in
{
  home = {
    packages = [
      pkgs.xwayland-satellite
      wrappedNiri
      wl-harmonograph
      # Portals for cross-desktop functionality (file pickers, screencasting, etc.)
      pkgs.xdg-desktop-portal-gtk
      pkgs.xdg-desktop-portal-gnome
      # Authentication agent, network, bluetooth (launched at startup)
      pkgs.polkit_gnome
      pkgs.networkmanagerapplet
      pkgs.blueman
      # File manager for portal file chooser
      pkgs.nautilus
      # Auto-rotation daemon for tablet/convertible devices
      pkgs.rot8
      # Wayland forwarding over SSH
      pkgs.waypipe
    ];

    # ── Mutable niri config ────────────────────────────────────────────
    # Copy the Nix-generated config.kdl to the XDG path as a real file
    # so Noctalia's template-apply.sh can add the include line and niri
    # can pick up runtime changes.  Seed noctalia.kdl with current theme
    # colours so the include never points at a missing file.
    activation.installNiriConfig = lib.hm.dag.entryAfter [ "linkGeneration" ] ''
      # Force the validation derivation to build
      : ${niriConfigValidated}

      niri_dir="''${XDG_CONFIG_HOME:-$HOME/.config}/niri"
      mkdir -p "$niri_dir"
      install -m 644 ${niriConfigFile} "$niri_dir/config.kdl"

      # Seed noctalia.kdl only if it doesn't exist yet — once
      # Noctalia's template processor runs, it owns this file.
      if [ ! -f "$niri_dir/noctalia.kdl" ]; then
        install -m 644 ${initialNoctaliaKdl} "$niri_dir/noctalia.kdl"
      fi
    '';

    # ── Make noctalia colors.json writable ─────────────────────────────
    # The Noctalia HM module writes colors.json as a nix-store symlink.
    # The template processor needs to overwrite it with generated
    # colours.  The activation script converts the symlink to a real
    # copy after linkGeneration.
    activation.makeNoctaliaColorsMutable = lib.hm.dag.entryAfter [ "linkGeneration" ] ''
      target="''${XDG_CONFIG_HOME:-$HOME/.config}/noctalia/colors.json"
      if [ -L "$target" ]; then
        content=$(cat "$target")
        rm "$target"
        printf '%s\n' "$content" > "$target"
      fi
    '';

    # Configure rot8 for automatic screen rotation
    # GPD Pocket 4 rotations mapped to match device orientation (270 default)
    file.".local/bin/rot8-niri-hook" = {
      text = ''
        #!/bin/sh
        # Log to file for debugging
        LOG="''${XDG_STATE_HOME:-$HOME/.local/state}/rot8-debug.log"
        mkdir -p "$(dirname "$LOG")"
        echo "$(date '+%Y-%m-%d %H:%M:%S') - Orientation: $ORIENTATION (prev: $PREV_ORIENTATION)" >> "$LOG"

        case "$ORIENTATION" in
          "normal")
            echo "  -> Applying transform 270" >> "$LOG"
            ${wrappedNiri}/bin/niri msg output ${config.monitors.builtin.name} transform 270
            ;;
          "90")
            echo "  -> Applying transform 180" >> "$LOG"
            ${wrappedNiri}/bin/niri msg output ${config.monitors.builtin.name} transform normal
            ;;
          "inverted")
            echo "  -> Applying transform 90" >> "$LOG"
            ${wrappedNiri}/bin/niri msg output ${config.monitors.builtin.name} transform 90
            ;;
          "270")
            echo "  -> Applying transform normal" >> "$LOG"
            ${wrappedNiri}/bin/niri msg output ${config.monitors.builtin.name} transform 180
            ;;
        esac
      '';
      executable = true;
    };
  };

  # ── Niri systemd service + colour sync ─────────────────────────────────
  systemd.user = {
    # Override the niri service to use the wrapped binary
    services.niri = {
      Unit = {
        Description = "A scrollable-tiling Wayland compositor";
        BindsTo = "graphical-session.target";
        Before = "graphical-session.target";
        Wants = [
          "graphical-session-pre.target"
          "xdg-desktop-autostart.target"
        ];
        After = "graphical-session-pre.target";
        # Prevent restarting the service on configuration changes
        X-RestartIfChanged = false;
        X-StopIfChanged = false;
      };
      Service = {
        Slice = "session.slice";
        Type = "notify";
        ExecStart = "${wrappedNiri}/bin/niri --session";
      };
    };

    # Noctalia's template processor writes noctalia.kdl when colours
    # change. Niri watches config.kdl but NOT included files, so we
    # need a path unit to detect noctalia.kdl changes and trigger a
    # config reload.
    paths.noctalia-niri-sync = {
      Unit.Description = "Watch noctalia.kdl for colour changes";
      Path.PathChanged = "%h/.config/niri/noctalia.kdl";
      Install.WantedBy = [ "default.target" ];
    };

    services.noctalia-niri-sync = {
      Unit.Description = "Reload niri config after noctalia colour change";
      Service = {
        Type = "oneshot";
        ExecStart = "${wrappedNiri}/bin/niri msg action load-config-file";
      };
    };
  };

  # Enable gnome-keyring service
  services.gnome-keyring = {
    enable = true;
    components = [ "secrets" ];
  };

  # Enable portals for file pickers, screencasting, etc.
  xdg.portal = {
    enable = true;
    extraPortals = [
      pkgs.xdg-desktop-portal-gtk
      pkgs.xdg-desktop-portal-gnome
    ];
    config = {
      common = {
        default = [ "gtk" ];
        "org.freedesktop.impl.portal.Secret" = [ "gnome-keyring" ];
      };
      niri = {
        default = [
          "gnome"
          "gtk"
        ];
        "org.freedesktop.impl.portal.Screenshot" = [ "gnome" ];
        "org.freedesktop.impl.portal.ScreenCast" = [ "gnome" ];
      };
    };
  };

  # force=true lets HM replace the previous real file on each activation
  xdg.configFile."noctalia/colors.json".force = true;

  # Set GNOME preferences for portal UI settings
  dconf.settings = {
    "org/gnome/desktop/interface" = {
      color-scheme = lib.mkDefault "prefer-dark";
    };
  };
}
