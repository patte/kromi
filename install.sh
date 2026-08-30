#!/usr/bin/env bash
# kromi installer — the two lines from the README, made one:
#
#   curl -fsSL https://raw.githubusercontent.com/patte/kromi/main/install.sh | bash
#
# When piped into bash, clones kromi into ~/.local/share/kromi, or pulls if it
# is already there. When run from a kromi checkout, links that checkout as-is,
# including uncommitted changes. Either way, bin/kromi is linked into
# ~/.local/bin. Setup is left for the user because it asks questions.
#
#   KROMI_REPO      where to clone from; setting it forces clone mode
#   KROMI_DIR       where to clone/update; setting it forces clone mode
#   KROMI_BIN_DIR   where to link kromi   (default ~/.local/bin)
set -euo pipefail

LOCAL_DIR=""
if [[ -z ${KROMI_DIR+x} && -z ${KROMI_REPO+x} && -n ${BASH_SOURCE[0]:-} && -f ${BASH_SOURCE[0]} ]]; then
  source_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)
  if [[ -x $source_dir/bin/kromi && -d $source_dir/apps && -d $source_dir/themes ]]; then
    LOCAL_DIR=$source_dir
  fi
fi

REPO=${KROMI_REPO:-https://github.com/patte/kromi}
DIR=${KROMI_DIR:-${LOCAL_DIR:-${XDG_DATA_HOME:-$HOME/.local/share}/kromi}}
BIN_DIR=${KROMI_BIN_DIR:-$HOME/.local/bin}

die() {
  printf 'kromi install: %s\n' "$*" >&2
  exit 1
}

is_kromi_command() {
  local command=$1 root
  [[ -n $command && -x $command ]] || return 1
  root=$(dirname "$(dirname "$command")")
  [[ $command == "$root/bin/kromi" && -d $root/apps && -d $root/themes ]]
}

if [[ -n $LOCAL_DIR ]]; then
  printf 'Using local checkout %s.\n' "$DIR"
else
  command -v git >/dev/null 2>&1 || die "git is required; install it and try again"

  # A .git is not proof of kromi: update only a checkout that has the program,
  # and link only one that still has it afterwards.
  if [[ -d $DIR/.git ]]; then
    [[ -x $DIR/bin/kromi ]] || die "$DIR is not a kromi checkout; set KROMI_DIR to another location"
    git -C "$DIR" pull --ff-only --quiet || die "could not update $DIR; run git pull there to inspect the error"
    printf 'Updated kromi in %s.\n' "$DIR"
  elif [[ -e $DIR ]]; then
    die "$DIR already exists and is not a git checkout; move it or set KROMI_DIR"
  else
    git clone --quiet "$REPO" "$DIR" || die "could not clone $REPO into $DIR"
    printf 'Installed kromi in %s.\n' "$DIR"
  fi
fi
[[ -x $DIR/bin/kromi ]] || die "$DIR/bin/kromi is missing or not executable"

# A regular file on PATH is not ours to take. A symlink may be repointed only
# when it leads to another recognizable kromi checkout; this lets `./install.sh`
# switch an installation between a cloned copy and the working tree.

target="$BIN_DIR/kromi"
if [[ -L $target ]]; then
  old_command=$(readlink -f "$target" 2>/dev/null || true)
  if [[ $old_command != "$DIR/bin/kromi" ]] && ! is_kromi_command "$old_command"; then
    die "$target points to $(readlink "$target"); remove it or set KROMI_BIN_DIR"
  fi
elif [[ -e $target ]]; then
  die "$target already exists; remove it or set KROMI_BIN_DIR"
fi

mkdir -p "$BIN_DIR"
ln -sfn "$DIR/bin/kromi" "$target"
printf 'Command installed as %s.\n' "$target"

# Name the command the way this shell can actually run it.
case ":$PATH:" in
  *":$BIN_DIR:"*)
    printf '\nNext: kromi setup\n'
    ;;
  *)
    printf '\n%s is not on your PATH, so `kromi` is not available by name yet.\n' "$BIN_DIR"
    printf 'Add that directory to PATH when convenient.\n'
    printf '\nNext: %s/kromi setup\n' "$BIN_DIR"
    ;;
esac
