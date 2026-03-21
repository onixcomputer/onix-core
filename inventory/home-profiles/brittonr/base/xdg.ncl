# XDG directories and MIME type associations — source of truth.
#
# Centralizes user directories and all default application mappings
# that are otherwise scattered across media-viewers, thunar, firefox,
# and typst modules.
#
# Consumed by: xdg.nix (home-manager xdg options)
# Validated at `ncl export` time.
#
# Workflow:
#   1. Edit this file
#   2. Run: ncl export inventory/home-profiles/brittonr/base/xdg.ncl
#   3. Commit .ncl
let NonEmpty =
  std.contract.from_validator (match {
    value if std.is_string value && std.string.length value > 0 => 'Ok,
    _ => 'Error { message = "must be a non-empty string" },
  }
  )
in

let MimeType =
  std.contract.from_validator (match {
    value if std.is_string value && std.string.contains "/" value => 'Ok,
    _ => 'Error { message = "must be a MIME type (contains /)" },
  }
  )
in

let DesktopEntry =
  std.contract.from_validator (match {
    value if std.is_string value && std.string.is_match "\\.desktop$" value => 'Ok,
    _ => 'Error { message = "must end with .desktop" },
  }
  )
in

{
  userDirs = {
    documents | NonEmpty = "$HOME/Documents",
    download | NonEmpty = "$HOME/Downloads",
    music | NonEmpty = "$HOME/Music",
    pictures | NonEmpty = "$HOME/Pictures",
    videos | NonEmpty = "$HOME/Videos",
    extra = {
      SCREENSHOTS | NonEmpty = "$HOME/Pictures/Screenshots",
      PROJECTS | NonEmpty = "$HOME/git",
    },
  },

  # All MIME type → desktop entry mappings in one place.
  # Grouped by category for readability; flattened by the Nix stub.
  mimeApps | { _ : { _ : Array DesktopEntry } } = {
    directories = {
      "inode/directory" = ["thunar.desktop"],
    },

    images = {
      "image/png" = ["org.gnome.gThumb.desktop"],
      "image/jpeg" = ["org.gnome.gThumb.desktop"],
      "image/jpg" = ["org.gnome.gThumb.desktop"],
      "image/gif" = ["org.gnome.gThumb.desktop"],
      "image/webp" = ["org.gnome.gThumb.desktop"],
      "image/bmp" = ["org.gnome.gThumb.desktop"],
      "image/svg+xml" = ["org.gnome.gThumb.desktop"],
      "image/tiff" = ["org.gnome.gThumb.desktop"],
    },

    video = {
      "video/mp4" = ["mpv.desktop"],
      "video/x-matroska" = ["mpv.desktop"],
      "video/webm" = ["mpv.desktop"],
      "video/avi" = ["mpv.desktop"],
      "video/quicktime" = ["mpv.desktop"],
    },

    documents = {
      "application/pdf" = ["org.gnome.Evince.desktop"],
    },

    web = {
      "x-scheme-handler/http" = ["librewolf.desktop"],
      "x-scheme-handler/https" = ["librewolf.desktop"],
      "text/html" = ["librewolf.desktop"],
      "application/xhtml+xml" = ["librewolf.desktop"],
    },

    typesetting = {
      "text/x-typst" = ["typstwriter.desktop"],
    },
  },
}
