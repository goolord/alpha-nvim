# tooling
  - `make test` runs the test suite in a headless neovim. it needs no plugins,
    and `tests/run.lua` is a plain list of cases, so adding one is a few lines.

  - stylua is used to format the lua code. `stylua lua/` should be good enough.
    I'm not going to deny your PR if it's not formatted, it's just there for
    people who want it.

  - There's also an editorconfig file, which you may need a plugin to use
    which will set some appropriate settings in your editor to hack on the code.

