# α alpha-nvim
`alpha` is a fast and fully programmable greeter for neovim.

share or snipe some custom themes @ https://github.com/goolord/alpha-nvim/discussions/16

## Quick Start
#### vim-startify theme
![glamor shot](https://user-images.githubusercontent.com/24906808/133367667-0f73e9e1-ea75-46d1-8e1b-ff0ecfeafeb1.png)
<details>
<summary>EXAMPLES</summary>

With [lazy.nvim](https://github.com/folke/lazy.nvim):
```lua
{
    'goolord/alpha-nvim',
    dependencies = { 'nvim-mini/mini.icons' },
    config = function ()
        require'alpha'.setup(require'alpha.themes.startify'.config)
    end
};
```
With packer:
```lua
use {
    'goolord/alpha-nvim',
    requires = { 'nvim-mini/mini.icons' },
    config = function ()
        require'alpha'.setup(require'alpha.themes.startify'.config)
    end
}
```
..or using paq:
```lua
require "paq" {
    "goolord/alpha-nvim";
    "nvim-mini/mini.icons";
}
require'alpha'.setup(require'alpha.themes.startify'.config)
```
</details>

#### dashboard-nvim theme
![glamor shot](https://user-images.githubusercontent.com/24906808/132604236-4f20adc4-706c-49b4-b473-ebfd6a7f0784.png)
<details>
<summary>EXAMPLES</summary>

With [lazy.nvim](https://github.com/folke/lazy.nvim):
```lua
{
    'goolord/alpha-nvim',
    config = function ()
        require'alpha'.setup(require'alpha.themes.dashboard'.config)
    end
};
```
With packer:
```lua
use {
    'goolord/alpha-nvim',
    config = function ()
        require'alpha'.setup(require'alpha.themes.dashboard'.config)
    end
}
```
..or using paq:
```lua
require "paq" {
    "goolord/alpha-nvim";
    "nvim-mini/mini.icons";
}
require'alpha'.setup(require'alpha.themes.dashboard'.config)
```
</details>

#### Theta theme
<details>
<summary>EXAMPLES</summary>

With [lazy.nvim](https://github.com/folke/lazy.nvim):
```lua
{
    'goolord/alpha-nvim',
    dependencies = {
        'nvim-mini/mini.icons',
        'nvim-lua/plenary.nvim'
    },
    config = function ()
        require'alpha'.setup(require'alpha.themes.theta'.config)
    end
};
```
With packer:
```lua
use {
    'goolord/alpha-nvim',
    requires = {
        'nvim-mini/mini.icons',
        'nvim-lua/plenary.nvim'
    },
    config = function ()
        require'alpha'.setup(require'alpha.themes.dashboard'.config)
    end
}
```
..or using paq:
```lua
require "paq" {
    "goolord/alpha-nvim";
    "nvim-mini/mini.icons";
    'nvim-lua/plenary.nvim';
}
require'alpha'.setup(require'alpha.themes.dashboard'.config)
```
</details>

if you want sessions, see
- [`Shatur/neovim-session-manager`](https://github.com/Shatur/neovim-session-manager)
- `:h :mks`

this theme makes some assumptions about your default keybindings
to customize the buttons, see `:h alpha-example`

#### File Icons

theta/startify theme support file icons, default is enabled and `mini` icon provider is used.

- [`nvim-tree/nvim-web-devicons`](https://github.com/nvim-tree/nvim-web-devicons)
- [`nvim-mini/mini.icons`](https://github.com/nvim-mini/mini.nvim/blob/main/readmes/mini-icons.md)

if you prefer `nvim-web-devicons` icon provider, use the following example with `lazy.nvim`:

```lua
  {
    "goolord/alpha-nvim",
    -- dependencies = { 'nvim-mini/mini.icons' },
    dependencies = { 'nvim-tree/nvim-web-devicons' },
    config = function()
      local startify = require("alpha.themes.startify")
      -- available: devicons, mini, default is mini
      -- if provider not loaded and enabled is true, it will try to use another provider
      startify.file_icons.provider = "devicons"
      require("alpha").setup(
        startify.config
      )
    end,
  },
```

## Elevator pitch
alpha is really a general purpose neovim ui library with some conveniences for writing a greeter ui.
it has a functional, data-oriented api design. themes are expressed entirely as data, which is what makes
alpha "fully programmable". alpha is also the fastest greeter I've benchmarked (which is why I daily drive it myself!).

## Profiling Results
![benchmark](https://user-images.githubusercontent.com/24906808/131830001-31523c86-fee2-4f90-b23d-4bd1e152a385.png)
- using [`lewis6991/impatient.nvim`](https://github.com/lewis6991/impatient.nvim)
- only config! doesn't measure drawing, some startup plugins won't measure drawing either

## Special Thanks
- https://github.com/glepnir/dashboard-nvim - inspiration, code reference
- https://github.com/mhinz/vim-startify     - inspiration
