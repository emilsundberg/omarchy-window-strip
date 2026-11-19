-- window_strip_modifier = "SUPER": Super+Tab switches, Super release commits,
-- Escape or Super+Escape cancels, and Omarchy's Super+Escape system menu is
-- only overridden while the strip is open.
local binds, events, commands = {}, {}, {}
local windows = {
  { mapped = true, workspace = { name = '1', special = false }, focus_history_id = 0, address = '0x1', title = 'First', class = 'chromium' },
  { mapped = true, workspace = { name = '1', special = false }, focus_history_id = 1, address = '0x2', title = 'Second', class = 'foot' },
}
local system_menu = function() end
binds['SUPER + ESCAPE'] = system_menu
binds['CTRL + TAB'] = 'browser'

-- Hyprland's unbind clears a key from every submap; binds made inside
-- define_submap only fire while that submap is active.
local submap_binds, current_submap, defining = {}, '', nil
hl = {
  unbind = function(key)
    binds[key] = nil
    submap_binds[key] = nil
  end,
  bind = function(key, callback) (defining or binds)[key] = callback end,
  define_submap = function(name, fn)
    assert(name == 'emil-altswitch')
    defining = submap_binds
    fn()
    defining = nil
  end,
  dsp = { submap = function(name) return { submap = name } end },
  dispatch = function(dispatcher) current_submap = dispatcher.submap == 'reset' and '' or dispatcher.submap end,
  on = function(event, callback) events[event] = callback end,
  exec_cmd = function(command) commands[#commands + 1] = command end,
  get_windows = function() return windows end,
  layer_rule = function() end,
}
window_strip_modifier = 'super'
dofile('altswitch.lua')

local function press(key)
  local map = current_submap == '' and binds or submap_binds
  assert(map[key], key .. ' is not bound in submap "' .. current_submap .. '"')
  map[key]()
end

local function lastContains(text)
  assert(commands[#commands]:find(text, 1, true), commands[#commands])
end

assert(binds['CTRL + TAB'] == 'browser', 'Ctrl+Tab must stay with applications')
assert(binds['SUPER + ESCAPE'] == system_menu, 'Super+Escape must stay the system menu')
assert(type(binds['SUPER + SHIFT + TAB']) == 'function')

press('SUPER + TAB')
lastContains('emil.altswitch show')
-- Ctrl release must not commit a Super+Tab switch.
local count = #commands
events['input.keyboard.key'](37, nil, 0)
assert(#commands == count)
events['input.keyboard.key'](133, nil, 0)
lastContains('address:0x2')

-- Super+Escape cancels while the strip is open, without opening the system menu.
press('SUPER + TAB')
assert(current_submap == 'emil-altswitch')
local menu_opened = false
binds['SUPER + ESCAPE'] = function() menu_opened = true end
press('SUPER + ESCAPE')
assert(not menu_opened, 'Super+Escape must not open the system menu during a switch')
assert(current_submap == '')
lastContains('emil.altswitch hide')
press('SUPER + ESCAPE')
assert(menu_opened, 'Super+Escape must be the system menu again afterwards')

press('SUPER + TAB')
events['input.keyboard.key'](9, nil, 1)
lastContains('emil.altswitch hide')
count = #commands
events['input.keyboard.key'](134, nil, 0)
assert(#commands == count)

print('Super modifier switching, release, Escape and Super+Escape cancel, and untouched bindings checks passed')
