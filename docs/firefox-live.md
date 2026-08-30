# Live Firefox switching

Normal Firefox profile linking applies a new palette the next time Firefox
starts. `kromi-firefox-live` is the optional way to recolour windows that are
already open.

This is a larger installation step than `kromi link`: Firefox runs privileged
JavaScript only from its installation directory, so the helper installs a
loader beside the program, usually as root. Firefox updates can replace that
directory and remove the loader; run the install command again after such an
update.

## Install

First remove ordinary Firefox profile linking, because the two mechanisms do
not compose:

```sh
kromi unlink firefox
kromi-firefox-live install
```

Then restart Firefox once. Future `kromi set` commands update open Firefox
windows immediately.

Useful commands:

```sh
kromi-firefox-live status
kromi-firefox-live install
kromi-firefox-live uninstall
```

`KROMI_FIREFOX_APP` can name Firefox's installation directory when it is not
in one of the usual system locations.

## Why linking must be removed

A stylesheet imported through `userChrome.css` loads before one registered by
the live loader and wins over it. Leaving a profile linked would pin the
palette Firefox started with and make the loader appear ineffective.

The commands guard both sides of this conflict: the installer warns about
linked profiles, and `kromi link firefox` refuses while the live loader is
installed. Other apps remain available to a bare `kromi link` as usual.

## How it works

The loader watches kromi's generated Firefox chrome, content, and mode files
and registers their stylesheets through Firefox's internal stylesheet service.
It also updates the website-appearance preference. Nothing from kromi is
written into Firefox profiles in this mode.

Each Firefox process listens on a Unix socket below
`$XDG_RUNTIME_DIR/kromi`. On every switch, kromi connects to each socket; the
connection itself is the complete notification, so no data is sent or read.
Opening the socket requires one of:

- `socat`
- a netcat implementation with `-U`
- `python3`

Without one of those, the loader falls back to checking the generated file. It
checks frequently for a short period after a switch, less often otherwise, and
pauses while the machine is idle.

The generated files are rendered and swapped into place together. The chrome
stylesheet acts as their change marker, so editing a different generated file
by hand will not notify Firefox until the marker changes. Run `touch
~/.local/state/kromi/current/firefox.css` or set the theme again.

## Remove it

```sh
kromi-firefox-live uninstall
```

After uninstalling, Firefox can be connected through ordinary profile linking
again:

```sh
kromi link firefox
```
