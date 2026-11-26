# x-lib-editor-vi

The vi editor for [x-lang](https://github.com/jonruttan/x-lang), written in x:
busybox's vi (editors/vi.c), its screen, its keys and its messages, as a
library.

x-lib-editor-vi holds the bundle `editor-vi`. It is a library: it has modules
and no entry. A program imports `editor/vi/editor` and runs the editor on the
terminal:

```x
(import editor/vi/editor)
(Vi main (list "notes.txt"))
```

`Vi main` takes the command line as busybox's vi does: `-c CMD`, `-R`
(read-only), `-H` (the features), then the files to edit in turn. It answers
the exit status.

## Using it

Installed under x's `bundles/` directory, an import of an `editor/vi/` module
finds it with nothing declared:

```sh
make install
```

A bundle that depends on it says so in its `bundle.xon`:

```x
(requires-bundle "editor-vi" "v0.1.0" "jonruttan/x-lib-editor-vi")
```

## Working on it

```sh
make check
```

## Licence

MIT No Attribution.
