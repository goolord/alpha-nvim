# alpha-nvim
`alpha` is a fast and highly customizable greeter for neovim.

See [Quick Start](#quick-start) for screenshots of the `dashboard-nvim` and `vim-startify` themes

## Quick Start
#### dashboard-nvim theme
![glamor shot](https://user-images.githubusercontent.com/24906808/131895631-96810a64-b528-430d-b08b-6542c2dededa.png)
```lua
use {
    'goolord/alpha-nvim',
    config = function ()
        require'alpha'.setup(require'alpha.themes.dashboard'.opts)
    end
}
```

#### vim-startify theme
![glamor shot](https://user-images.githubusercontent.com/24906808/132074699-a837806e-f845-4779-8e82-5bd9b535b979.png)
```lua
use {
    'goolord/alpha-nvim',
    requires = { 'kyazdani42/nvim-web-devicons' },
    config = function ()
        require'alpha'.setup(require'alpha.themes.startify'.opts)
    end
}
```
## Profiling Results
![benchmark](https://user-images.githubusercontent.com/24906808/131830001-31523c86-fee2-4f90-b23d-4bd1e152a385.png)
*using https://github.com/lewis6991/impatient.nvim*

## TODO
- maybe center however something like Goyo does it
- what is that annoying text that appears on the command-line
  when you start up? can't tell by looking at anyone else's code

## Special Thanks
- https://github.com/glepnir/dashboard-nvim - inspiration, code reference
- https://github.com/mhinz/vim-startify     - inspiration
