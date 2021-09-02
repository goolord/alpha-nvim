# alpha-nvim
![glamor shot](https://user-images.githubusercontent.com/24906808/131895631-96810a64-b528-430d-b08b-6542c2dededa.png)
sexy! wow!

![benchmark](https://user-images.githubusercontent.com/24906808/131830001-31523c86-fee2-4f90-b23d-4bd1e152a385.png)
fast!

### Quick Start
```lua
use {
    'goolord/alpha-nvim',
    config = function ()
        require'alpha'.setup(require'alpha.themes.dashboard'.opts)
    end
}
```

## TODO
- maybe center however something like Goyo does it
- definitely room for improvement performance wise. 
  there is a lot going on when the screen repaints wrt mutating global state
- also, there should probably be less global state
- what is that annoying text that appears on the command-line
  when you start up? can't tell by looking at anyone else's code

## Special Thanks
- https://github.com/glepnir/dashboard-nvim - inspiration, code reference
- https://github.com/mhinz/vim-startify     - inspiration
