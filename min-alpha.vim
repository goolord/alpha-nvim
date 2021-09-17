set rtp-=stdpath('data')/site
source lua/alpha.lua
source lua/alpha/themes/dashboard.lua
lua require'alpha'.setup(require'alpha.themes.dashboard'.opts)
