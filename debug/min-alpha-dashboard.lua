vim.opt.rtp:append(vim.fn.fnamemodify(vim.fn.getcwd(), ':p:h:h'))

require'alpha'.setup(require'alpha.themes.dashboard'.opts)
