.PHONY: test

test:
	nvim --clean --cmd 'set rtp+=.' -l tests/run.lua
