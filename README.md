# α alpha-nvim
`alpha` is a fast and fully programmable greeter for neovim.

share or snipe some custom themes @ https://github.com/goolord/alpha-nvim/discussions/16

## Quick Start
#### vim-startify theme
![glamor shot](https://user-images.githubusercontent.com/24906808/133367667-0f73e9e1-ea75-46d1-8e1b-ff0ecfeafeb1.png)
With packer:
```lua
use {
    'goolord/alpha-nvim',
    requires = { 'nvim-tree/nvim-web-devicons' },
    config = function ()
        require'alpha'.setup(require'alpha.themes.startify'.config)
    end
}
```
..or using paq:
```lua
require "paq" {
    "goolord/alpha-nvim";
    "nvim-tree/nvim-web-devicons";
}
require'alpha'.setup(require'alpha.themes.startify'.config)
```
#### dashboard-nvim theme
![glamor shot](https://user-images.githubusercontent.com/24906808/132604236-4f20adc4-706c-49b4-b473-ebfd6a7f0784.png)
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
    "nvim-tree/nvim-web-devicons";
}
require'alpha'.setup(require'alpha.themes.dashboard'.config)
```
if you want sessions, see 
- https://github.com/Shatur/neovim-session-manager
- :h :mks

this theme makes some assumptions about your default keybindings
to customize the buttons, see :h alpha-example

## Elevator pitch
alpha is really a general purpose neovim ui library with some conveniences for writing a greeter ui.
it has a functional, data-oriented api design. themes are expressed entirely as data, which is what makes
alpha "fully programmable". alpha is also the fastest greeter I've benchmarked (which is why I daily drive it myself!).

## Profiling Results
![benchmark](https://user-images.githubusercontent.com/24906808/131830001-31523c86-fee2-4f90-b23d-4bd1e152a385.png)
- using https://github.com/lewis6991/impatient.nvim
- only config! doesn't measure drawing, some startup plugins won't measure drawing either

## Special Thanks
- https://github.com/glepnir/dashboard-nvim - inspiration, code reference
- https://github.com/mhinz/vim-startify     - inspiration
