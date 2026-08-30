# kromi wallpaper fetch|list — fetch theme wallpapers into ~/.config/kromi/wallpapers.
#
# Sourced by `kromi` only for these two subcommands: the rest of the tool never
# touches the network and needs nothing but bash and sed. This needs git, and
# runs about once.
#
# kromi ships no wallpapers. They belong to whoever made them, are not
# kromi's to redistribute, and the upstream set mixes freely licensed
# photography with stills and artwork that plainly are not. Fetching them
# copies someone else's files onto your disk for your own use; it does not
# make them yours. Point KROMI_WALLPAPERS_REPO somewhere else if you would
# rather not.

WALLPAPERS_REPO=${KROMI_WALLPAPERS_REPO:-https://github.com/basecamp/omarchy.git}
WALLPAPERS_REF=${KROMI_WALLPAPERS_REF:-v3.8.4}
WALLPAPERS_DEST="$KROMI_CONFIG/wallpapers"

# Global, because an EXIT trap fires long after any function local is gone.
FETCH_WORKDIR=""
fetch_cleanup() { [[ -n ${FETCH_WORKDIR:-} ]] && rm -rf "$FETCH_WORKDIR"; }

# Metadata only: --filter=blob:none means no image is fetched until checkout.
clone_index() {
  git clone --depth 1 --filter=blob:none --no-checkout --sparse \
    --branch "$WALLPAPERS_REF" --quiet "$WALLPAPERS_REPO" "$1" 2>/dev/null ||
    die "could not clone $WALLPAPERS_REPO at $WALLPAPERS_REF"
}

# Upstream stores them as themes/<name>/backgrounds/.
wallpaper_fetch_list() {
  command -v git >/dev/null 2>&1 || die "git is required to fetch wallpapers"
  FETCH_WORKDIR=$(mktemp -d)
  trap fetch_cleanup EXIT

  clone_index "$FETCH_WORKDIR"
  git -C "$FETCH_WORKDIR" ls-tree -r --name-only HEAD -- themes |
    awk -F/ '$3 == "backgrounds" && NF == 4 { count[$2]++ }
             END { for (t in count) printf "%-20s %d\n", t, count[t] }' |
    sort
}

wallpaper_fetch() {
  command -v git >/dev/null 2>&1 || die "git is required to fetch wallpapers"
  local -a themes=("$@")
  ((${#themes[@]})) || mapfile -t themes < <(list_themes)
  ((${#themes[@]})) || die "no themes found"

  FETCH_WORKDIR=$(mktemp -d)
  trap fetch_cleanup EXIT
  local tmp=$FETCH_WORKDIR

  printf 'Downloading wallpapers from %s (%s)...\n' "$WALLPAPERS_REPO" "$WALLPAPERS_REF"
  clone_index "$tmp"

  # Cone mode takes directories, so name each one rather than globbing.
  local -a paths=()
  local theme
  for theme in "${themes[@]}"; do
    paths+=("themes/$theme/backgrounds")
  done

  git -C "$tmp" sparse-checkout set "${paths[@]}" >/dev/null 2>&1 || true
  git -C "$tmp" checkout --quiet "$WALLPAPERS_REF" 2>/dev/null || true

  local copied=0 kept=0 missing=0 src dest_dir name
  for theme in "${themes[@]}"; do
    if [[ ! -d $tmp/themes/$theme/backgrounds ]]; then
      missing=$((missing + 1))
      continue
    fi

    dest_dir="$WALLPAPERS_DEST/$theme"
    mkdir -p "$dest_dir"

    for src in "$tmp/themes/$theme/backgrounds"/*; do
      [[ -f $src ]] || continue
      name=$(basename "$src")
      # Never clobber: a picture you put there yourself wins.
      if [[ -e $dest_dir/$name ]]; then
        kept=$((kept + 1))
        continue
      fi
      cp "$src" "$dest_dir/$name"
      copied=$((copied + 1))
    done

    rmdir "$dest_dir" 2>/dev/null || true
  done

  printf 'Wallpapers: %d downloaded, %d already present, %d unavailable.\n' \
    "$copied" "$kept" "$missing"
  printf 'Saved in %s.\n' "$WALLPAPERS_DEST"
}
