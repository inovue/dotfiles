-- Windows host WezTerm config (synced to %USERPROFILE%\.wezterm.lua).
-- Source of truth: windows/wezterm/wezterm.lua in the dotfiles repo.
-- Not managed by GNU Stow / Ansible.

local wezterm = require 'wezterm'
local act = wezterm.action
local config = wezterm.config_builder()

-- Kitty protocols: graphics for terminal-browser.
-- keyboard OFF: with herdr, IME 1-char Composed commits are dropped
-- (wezterm#7944, unmerged). Re-enable after that lands in nightly.
config.enable_kitty_graphics = true
config.enable_kitty_keyboard = false

config.max_fps = 120
config.prefer_egl = true
config.font = wezterm.font_with_fallback({ 'HackGen Console NF' })
config.color_scheme = 'Catppuccin Mocha'

-- First pane: WSL home. There is no first-class "always home for new tabs" option;
-- new tabs otherwise inherit OSC 7 / wsl.exe cwd. Force ~ via SpawnCommand.
-- https://github.com/wezterm/wezterm/issues/5038
config.default_domain = 'WSL:Ubuntu'
local wsl_domains = wezterm.default_wsl_domains()
for _, dom in ipairs(wsl_domains) do
  if dom.name == 'WSL:Ubuntu' then
    dom.default_cwd = '~'
  end
end
config.wsl_domains = wsl_domains

local spawn_home = {
  domain = { DomainName = 'WSL:Ubuntu' },
  cwd = '~',
}

wezterm.on('new-tab-button-click', function(window, pane, button, default_action)
  if button == 'Left' then
    window:perform_action(act.SpawnCommandInNewTab(spawn_home), pane)
    return false
  end
  if default_action then
    window:perform_action(default_action, pane)
  end
  return false
end)

config.keys = {
  { key = 'v', mods = 'CTRL', action = act.PasteFrom 'Clipboard' },
  { key = 'V', mods = 'CTRL|SHIFT', action = act.PasteFrom 'Clipboard' },
  { key = 't', mods = 'CTRL|SHIFT', action = act.SpawnCommandInNewTab(spawn_home) },
  { key = 'n', mods = 'CTRL|SHIFT', action = act.SpawnCommandInNewWindow(spawn_home) },
}

return config
