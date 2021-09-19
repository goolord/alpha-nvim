vim.opt.rtp:append(vim.fn.fnamemodify(vim.fn.getcwd(), ':p:h:h'))
vim.cmd[[rshada ~/.local/share/nvim/shada/main.shada]]
require'alpha'.setup(require'alpha.themes.startify'.opts)
