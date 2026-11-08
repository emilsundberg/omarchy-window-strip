-- window_strip_modifier = "SUPER": Super+Tab switches, Super release commits,
-- Escape cancels, and Omarchy's Super+Escape system menu is left alone.
local binds, events, commands = {}, {}, {}
local windows = {
  { mapped = true, workspace = { name = '1', special = false }, focus_history_id = 0, address = '0x1', title = 'First', class = 'chromium' },
  { mapped = true, workspace = { name = '1', special = false }, focus_history_id = 1, address = '0x2', title = 'Second', class = 'foot' },
}
local system_menu = function() end
binds['SUPER + ESCAPE'] = system_menu
binds['CTRL + TAB'] = 'browser'

hl = {
  unbind = function(key) binds[key] = nil end,
  bind = function(key, callback) binds[key] = callback end,
  on = function(event, callback) events[event] = callback end,
  exec_cmd = function(command) commands[#commands + 1] = command end,
  get_windows = function() return windows end,
  layer_rule = function() end,
}
window_strip_modifier = 'super'
dofile('altswitch.lua')

local function lastContains(text)
  assert(commands[#commands]:find(text, 1, true), commands[#commands])
end

assert(binds['CTRL + TAB'] == 'browser', 'Ctrl+Tab must stay with applications')
assert(binds['SUPER + ESCAPE'] == system_menu, 'Super+Escape must stay the system menu')
assert(type(binds['SUPER + SHIFT + TAB']) == 'function')

binds['SUPER + TAB']()
lastContains('emil.altswitch show')
-- Ctrl release must not commit a Super+Tab switch.
local count = #commands
events['input.keyboard.key'](37, nil, 0)
assert(#commands == count)
events['input.keyboard.key'](133, nil, 0)
lastContains('address:0x2')

binds['SUPER + TAB']()
events['input.keyboard.key'](9, nil, 1)
lastContains('emil.altswitch hide')
count = #commands
events['input.keyboard.key'](134, nil, 0)
assert(#commands == count)

print('Super modifier switching, release, Escape cancel, and untouched bindings checks passed')
