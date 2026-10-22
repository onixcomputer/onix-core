#!/usr/bin/env bash
set -euo pipefail

revision=4e505f348e3290dfd16e0e0794a14fbef316e85a

if [[ $# -ne 1 ]]; then
  printf 'usage: %s <meshtop-git-checkout>\n' "$0" >&2
  exit 2
fi

source_dir=$(realpath -e -- "$1")
script_dir=$(CDPATH= cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
package_dir="$script_dir/../pkgs/meshtop"
destination="$package_dir/source"

if [[ ! -d "$source_dir" ]] || \
   [[ $(git -C "$source_dir" rev-parse --show-toplevel 2>/dev/null) != "$source_dir" ]]; then
  echo 'expected the root of a meshtop Git checkout' >&2
  exit 1
fi
if [[ $(git -C "$source_dir" rev-parse HEAD) != "$revision" ]]; then
  printf 'meshtop checkout must be at %s\n' "$revision" >&2
  exit 1
fi
if [[ -n $(git -C "$source_dir" status --porcelain=v1 --untracked-files=all) ]]; then
  echo 'meshtop checkout must be clean' >&2
  exit 1
fi

# Stage only source files used by the package, never the checkout's Git metadata or build output.
staging=$(mktemp -d "$package_dir/.meshtop-source.XXXXXXXX")
backup="$package_dir/.meshtop-previous.$$"
cleanup() {
  rm -rf -- "$staging"
  if [[ -e "$backup" && ! -e "$destination" ]]; then
    mv -- "$backup" "$destination"
  fi
}
trap cleanup EXIT

for name in Cargo.toml Cargo.lock README.md; do
  git -C "$source_dir" ls-files --error-unmatch -- "$name" > /dev/null
  cp -- "$source_dir/$name" "$staging/$name"
done
mkdir -- "$staging/src"
shopt -s nullglob
sources=("$source_dir"/src/*.rs)
if [[ ${#sources[@]} -eq 0 ]]; then
  echo 'meshtop checkout has no Rust source files' >&2
  exit 1
fi
for file in "${sources[@]}"; do
  relative="src/${file##*/}"
  git -C "$source_dir" ls-files --error-unmatch -- "$relative" > /dev/null
  cp -- "$file" "$staging/$relative"
done

if [[ -e "$destination" ]]; then
  if [[ -e "$backup" ]]; then
    echo "refusing to overwrite $backup" >&2
    exit 1
  fi
  mv -- "$destination" "$backup"
fi
mv -- "$staging" "$destination"
printf '%s\n' "$revision" > "$package_dir/SOURCE_REVISION"
if [[ -e "$backup" ]]; then
  rm -rf -- "$backup"
fi
