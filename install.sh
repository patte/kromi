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

command -v git >/dev/null 2>&1 || die "git is required"

# A .git is not proof of kromi: update only a checkout that has the program.
if [[ -d $DIR/.git ]]; then
  [[ -x $DIR/bin/kromi ]] || die "$DIR is not a kromi checkout (no bin/kromi); set KROMI_DIR"
  git -C "$DIR" pull --ff-only --quiet || die "could not update $DIR; pull it by hand"
  printf 'updated %s\n' "$DIR"
elif [[ -e $DIR ]]; then
  die "$DIR exists and is not a git checkout; move it aside, or set KROMI_DIR"
else
  git clone --quiet "$REPO" "$DIR" || die "could not clone $REPO"
  [[ -x $DIR/bin/kromi ]] || die "$REPO is not kromi (no bin/kromi in the clone)"
  printf 'installed %s\n' "$DIR"
fi

# A name on PATH is not ours to take: link over nothing, or over a link that
# already points into this checkout.

target="$BIN_DIR/kromi"
if [[ -L $target ]]; then
  case $(readlink "$target") in
    "$DIR"/*) ;;
    *) die "$target is a link to $(readlink "$target"), not to $DIR; remove it first" ;;
  esac
elif [[ -e $target ]]; then
  die "$target exists and is not a link to $DIR; remove it first, or set KROMI_BIN_DIR"
fi

mkdir -p "$BIN_DIR"
ln -sfn "$DIR/bin/kromi" "$target"
printf 'linked %s\n' "$target"

case ":$PATH:" in
  *":$BIN_DIR:"*) ;;
  *) printf '\nnote: %s is not on your PATH; add it, or call %s/kromi by path\n' "$BIN_DIR" "$BIN_DIR" ;;
esac

printf '\nnext: kromi setup\n'
