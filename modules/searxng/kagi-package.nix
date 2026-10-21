{
  pkgs,
  enableKagi ? true,
  enableDeveloperEngines ? false,
  enableTidal ? false,
}:
let
  noogleData = pkgs.fetchurl {
    url = "https://noogle.dev/api/v1/data";
    sha256 = "09ad42np1fy42vqvccwch576sh8vj03jbhxb3in70b41kgyw6pls";
  };
in
pkgs.searxng.overrideAttrs (old: {
  patches = (old.patches or [ ]) ++ pkgs.lib.optional enableKagi ./kagi-access-context.patch;
  postPatch =
    (old.postPatch or "")
    + pkgs.lib.optionalString enableKagi ''
      cp ${./kagi_session.py} searx/engines/kagi_session.py
      cp ${./kagi_session_core.py} searx/kagi_session_core.py
      cp ${./kagi_unlock.py} searx/kagi_unlock.py
      cp ${./kagi_health.py} searx/kagi_health.py
      cp ${./kagi-access.html} searx/templates/simple/kagi-access.html
      cp ${./kagi-locked-engine.html} searx/templates/simple/kagi-locked-engine.html
      cp ${./kagi-unlock.js} searx/static/kagi-unlock.js
      substituteInPlace searx/templates/simple/base.html \
        --replace-fail '{% block content %}' \
        "{% if endpoint in ['preferences', 'results'] %}{% include 'simple/kagi-access.html' %}{% endif %}{% block content %}"
      substituteInPlace searx/templates/simple/preferences/engines.html \
        --replace-fail '{%- for group, group_bang, engines in engines_by_category[categ] | group_engines_in_tab -%}' \
        "{% include 'simple/kagi-locked-engine.html' %}{%- for group, group_bang, engines in engines_by_category[categ] | group_engines_in_tab -%}"
      PYTHONPYCACHEPREFIX="$TMPDIR/kagi-compile-cache" \
        ${pkgs.python3.interpreter} -m py_compile searx/webapp.py searx/kagi_unlock.py
    ''
    + pkgs.lib.optionalString enableTidal ''
      cp ${./tidal_core.py} searx/tidal_core.py
      cp ${./tidal_catalog.py} searx/engines/tidal_catalog.py
      cp ${./tidal_credentials.py} searx/tidal_credentials.py
    ''
    + pkgs.lib.optionalString enableDeveloperEngines ''
      cp ${./specialist_core.py} searx/specialist_core.py
      cp ${./nix_options.py} searx/engines/nix_options.py
      cp ${./noogle_catalog.py} searx/engines/noogle_catalog.py
      cp ${noogleData} searx/data/noogle-catalog.json
      cp ${./noogle-notices.txt} searx/data/noogle-notices.txt
    '';
})
