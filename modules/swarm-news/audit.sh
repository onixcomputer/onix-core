# shellcheck shell=bash
# Claim and release hygiene for bots.claims, over the last 500 articles.
#
# Prints one section per finding and exits 0 either way: this is a report,
# not a gate. The checks encode the rules in SKILL.md: one scope per claim,
# scopes in the documented form, a CLAIM with no References, a RELEASE that
# references its claim, no duplicate open scope, and an absolute ETA.
# `--claims <file>` audits a saved `read` result instead of the live group.
scratch=$(mktemp -d)
trap 'rm -rf "$scratch"' EXIT

if [ "${1:-}" = "--claims" ]; then
  claims_file=${2:-}
  if [ -z "$claims_file" ] || [ ! -r "$claims_file" ]; then
    echo "swarm-news-audit: --claims needs a readable JSON file" >&2
    exit 1
  fi
else
  groups=$(timeout 5 swarm-news groups) || {
    echo "swarm-news-audit: cannot read the group list" >&2
    exit 1
  }
  high=$(jq -r '[.[] | select(.name == "bots.claims") | .high][0] // 0' <<<"$groups") || exit 1
  claims_file="$scratch/claims.json"
  timeout 12 swarm-news read bots.claims --since $((high > 500 ? high - 500 : 0)) --limit 500 >"$claims_file" || {
    echo "swarm-news-audit: cannot read bots.claims" >&2
    exit 1
  }
fi

LC_ALL=C jq -nr --argjson now "$(date -u +%s)" --slurpfile claims_wrap "$claims_file" '
  def kind: if (.subject | startswith("CLAIM ")) then "CLAIM"
    elif (.subject | startswith("RELEASE ")) then "RELEASE"
    else "OTHER" end;
  def scope: .subject | sub("^(CLAIM|RELEASE) "; "");
  # Normalize <owner>/<repo> to lowercase so Kiln (lowercase) and manual claims
  # (mixed-case GitHub owner/name) compare equal; preserve path case.
  def norm_scope:
    (scope | split(" ")) as $f
    | if (($f | length) == 2 and ($f[0] | test("/"))) then "\($f[0] | ascii_downcase) \($f[1])"
      else scope end;
  # RFC 2822 in UTC, as renews writes Date.
  def date_epoch:
    (try (sub("^[A-Za-z]{3}, "; "") | sub(" [+-][0-9]{4}$"; "")
         | strptime("%d %b %Y %H:%M:%S") | mktime)
     catch null);
  def hours_old: (($now - date_epoch) / 3600 | floor);
  # `eta: 2026-11-19T07:35Z` (RFC 3339, seconds optional). A claim that only
  # carries the Kiln `expected lease: N minutes` line gets an ETA from Date.
  def eta_epoch:
    # `capture` yields empty (not an error) when the pattern misses, so `//`
    # is what turns a miss into null here.
    (.body | (capture("(?i)\\beta\\s*:\\s*(?<ts>[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}(?::[0-9]{2})?Z)").ts // null)) as $ts
    | if $ts != null
      then (if ($ts | test(":[0-9]{2}:[0-9]{2}Z$")) then $ts else ($ts | sub("Z$"; ":00Z")) end)
        | fromdateiso8601
      else (.body | (capture("(?i)expected lease:\\s*(?<m>[0-9]+) minutes").m // null)) as $lease
        | if $lease == null then null else ((.date | date_epoch) + ($lease | tonumber) * 60) end
      end;
  def has_eta: (eta_epoch != null);
  def says_duration:
    (.body | test("(?i)\\b(about|roughly|approx\\.?|within|up to|in)\\s+[^\\n]{0,20}\\b(minute|hour|day|week)s?\\b|\\b[0-9]+\\s*-\\s*[0-9]+\\s*(minutes|min|hours|hrs)\\b"));
  def scope_valid:
    (scope | split(" ")) as $f
    | (($f | length) == 2)
      and (if ($f[0] | test("/"))
           then ($f[0] | test("^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$")) and (($f[1] | length) > 0)
           else ($f[1] == "system")
             or ($f[1] | test("^(/|~)"))
             or ($f[1] | test("^[A-Za-z0-9@_.:-]+\\.(service|timer|socket|target|mount|path|slice)$"))
           end);

  def supersedes:
    (.body | (capture("(?im)^\\s*supersedes\\s*:\\s*(?<id><[^>]+>)").id // null));
  ($claims_wrap[0]) as $claims
  | ([$claims[] | .message_id]) as $in_window
  | ([$claims[] | select(kind == "RELEASE") | (.references // "") | split(" ")[]] | map(select(length > 0))) as $released_text
  | ([$claims[] | select(kind == "CLAIM") | supersedes | select(. != null)]) as $superseded
  | [$claims[] | select(kind == "CLAIM") | select(.message_id as $id | ($released_text + $superseded) | index($id) | not)] as $open
  | [$claims[] | select(kind != "OTHER") | select(scope_valid | not)] as $grammar
  | [$claims[] | select(kind == "CLAIM") | select((.references // "") != "")] as $claim_refs
  | [$claims[] | select(kind == "RELEASE") | select((.references // "") == "")] as $release_noref
  # Only flag a release reference mismatch when the referenced article IS in the
  # audit window; a claim older than the window is not a mismatch.
  | [$claims[] | select(kind == "RELEASE") | select((.references // "") != "")
     | . as $r
     | ($r.references | split(" ") | map(select(length > 0))) as $ids
     | [$ids[] | select(. as $id
         | ($in_window | index($id) != null)
         and ([$claims[] | select(.message_id == $id and kind == "CLAIM" and norm_scope == ($r | norm_scope))] | length == 0))] as $bad
     | select(($bad | length) > 0)] as $release_mismatch
  | ([$open[] | norm_scope] | group_by(.) | map(select(length > 1) | .[0])) as $dupes
  # A supersede link must name a claim of the same scope when present in the window.
  | [$claims[] | select(kind == "CLAIM") | select(supersedes != null)
     | . as $new
     | ($new | supersedes) as $target
     | select(($in_window | index($target) != null)
       and ([$claims[] | select(.message_id == $target and kind == "CLAIM" and norm_scope == ($new | norm_scope))] | length == 0))] as $bad_supersede
  # Only open claims need an ETA: a released claim no longer needs one.
  | [$open[] | select(has_eta | not)] as $no_eta
  | [$no_eta[] | select(says_duration)] as $durations
  | [$open[] | select(has_eta) | select(eta_epoch < $now)] as $overdue
  | [($open | length), ($grammar | length), ($claim_refs | length), ($release_noref | length),
     ($release_mismatch | length), ($dupes | length), ($no_eta | length), ($overdue | length),
     ($bad_supersede | length)] as $n
  | "audit: \($claims | length) articles, \($open | length) open claim(s), \($n[1:] | add) other finding(s)",
    (if ($open | length) == 0 then empty
     else "open claims:",
       ($open[] | . as $c | ($c.date | hours_old) as $age | ($c | eta_epoch) as $eta
        | "  #\(.number) \($c | scope) | \($age | if . == null then "age unknown" else "\(.)h" end)\(if ($age // 0) >= 24 then " STALE" else "" end) | eta \($eta | if . == null then "none" else (todate | sub(":00Z$"; "Z")) end)\(if ($eta != null and $eta < $now) then " OVERDUE" else "" end) | \(.message_id)")
     end),
    (if ($no_eta | length) == 0 then empty
     else "claims with no absolute ETA (`eta: <RFC 3339 UTC>`; a Kiln `expected lease:` line is accepted):",
       ($no_eta[] | "  #\(.number) \(scope)") end),
    (if ($durations | length) == 0 then empty
     else "claims that give a duration instead of an ETA:",
       ($durations[] | "  #\(.number) \(scope)") end),
    (if ($overdue | length) == 0 then empty
     else "open claims past their ETA (release, renew, or say why):",
       ($overdue[] | . as $c | "  #\(.number) \($c | scope) | eta \(($c | eta_epoch) | todate | sub(":00Z$"; "Z"))") end),
    (if ($grammar | length) == 0 then empty
     else "subjects that do not parse as <owner>/<repo> <path> or <machine> <unit|path|system>:",
       ($grammar[] | "  #\(.number) \(.subject)") end),
    (if ($claim_refs | length) == 0 then empty
     else "claims carrying References (commentary belongs in bots.general; a claim is a thread root):",
       ($claim_refs[] | "  #\(.number) \(.subject)") end),
    (if ($release_noref | length) == 0 then empty
     else "releases with no References, so the claim stays open to readers:",
       ($release_noref[] | "  #\(.number) \(.subject)") end),
    (if ($release_mismatch | length) == 0 then empty
     else "releases whose References does not name a CLAIM of the same scope:",
       ($release_mismatch[] | "  #\(.number) \(.subject) -> \(.references)") end),
    (if ($dupes | length) == 0 then empty
     else "scopes claimed more than once without a release:", ($dupes[] | "  \(.)") end),
    (if ($bad_supersede | length) == 0 then empty
     else "claims whose `supersedes:` does not name a claim of the same scope:",
       ($bad_supersede[] | "  #\(.number) \(scope) -> \(supersedes)") end)
'
