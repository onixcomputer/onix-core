{ pkgs }:
pkgs.searxng.overrideAttrs (old: {
  patches = (old.patches or [ ]) ++ [ ./kagi-access-context.patch ];
  postPatch = (old.postPatch or "") + ''
    cp ${./kagi_session.py} searx/engines/kagi_session.py
    cp ${./kagi_session_core.py} searx/kagi_session_core.py
    cp ${./kagi_unlock.py} searx/kagi_unlock.py
    cp ${./kagi-access.html} searx/templates/simple/kagi-access.html
    cp ${./kagi-unlock.js} searx/static/kagi-unlock.js
    substituteInPlace searx/templates/simple/base.html \
      --replace-fail '{% block content %}' \
      "{% if endpoint in ['preferences', 'results'] %}{% include 'simple/kagi-access.html' %}{% endif %}{% block content %}"
    PYTHONPYCACHEPREFIX="$TMPDIR/kagi-compile-cache" \
      ${pkgs.python3.interpreter} -m py_compile searx/webapp.py searx/kagi_unlock.py
  '';
})
