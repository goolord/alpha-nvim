LJ 
@alpha.lua§ !h£(  T+  4  77>)     T 4  77  T4  77  T4  77>	  T	4  74  7	7
% >  TG  4  77> T4  77) ) > 4  77  >4  77  T4  77 7>  T4  77% >G  3 ::2  :2  :+ 7%  >4 777 >4 777 >+ 7   >G   Àkeymaps	drawenablealpha_ui_G
alpharegister_uicursor_jumps_presscursor_jumpswindowbuffer cursor_ixwin_width 	line Save your changes first.nvim_err_writelngetmodifiedopt_localhiddennvim_win_set_bufnvim_create_bufnvim_get_current_buf-c	argvvtbl_contains	argcfnmodifiableinsertmodeonvim_get_current_winapivim 							






  """""$$$$$$%%%%%%&&&&&(options ui on_vimenter  iopts  iwindow abuffer `state I ¼  1
,   4  7% >G  ý 
        command! Alpha lua require'alpha'.start(false)
        command! AlphaRedraw call v:lua.alpha_ui.alpha.draw()
        augroup alpha_start
        au!
        autocmd VimEnter * nested lua require'alpha'.start(true)
        augroup END
    cmdvim		
options opts      + A4   % > )  1 1 3 ::0  H 
start
setup    gamma-uirequire/;=>?@@ui options start setup   