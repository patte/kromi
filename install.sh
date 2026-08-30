#!/usr/bin/env bash
# kromi installer — the two lines from the README, made one:
#
#   curl -fsSL https://raw.githubusercontent.com/patte/kromi/main/install.sh | bash
#
# Clones kromi into ~/.local/share/kromi, or pulls if it is already there —
# so this is the update path as well — and links bin/kromi into ~/.local/bin.
# It ends by saying what to run next rather than running it: setup asks
# questions, and a script fed through a pipe has no way to answer them.
#
#   KROMI_REPO      where to clone from
#   KROMI_DIR       where to put it       (default ~/.local/share/kromi)
#   KROMI_BIN_DIR   where to link kromi   (default ~/.local/bin)
set -euo pipefail

REPO=${KROMI_REPO:-https://github.com/patte/kromi}
DIR=${KROMI_DIR:-${XDG_DATA_HOME:-$HOME/.local/share}/kromi}
BIN_DIR=${KROMI_BIN_DIR:-$HOME/.local/bin}

die() {
  printf 'kromi install: %s\n' "$*" >&2
  exit 1
}

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
[[ -x $DIR/bin/kromi ]] || die "$DIR/bin/kromi is missing or not executable"

# A name on PATH is not ours to take: link over nothing, or over a link that
# already points into this checkout.

target="$BIN_DIR/kromi"
if [[ -L $target ]]; then
  case $(readlink "$target") in
    "$DIR"/*) ;;
    *) die "$target points to $(readlink "$target"); remove it or set KROMI_BIN_DIR" ;;
  esac
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
