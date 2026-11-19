local binds, events, commands = {}, {}, {}
local windows = {
  { mapped = true, workspace = { name = '2', special = false }, focus_history_id = 2, address = '0x3', title = 'Third', class = 'foot' },
  { mapped = true, workspace = { name = '1', special = false }, focus_history_id = 0, address = '0x1', title = 'First', class = 'chromium' },
  { mapped = true, workspace = { name = '1', special = false }, focus_history_id = 1, address = '0x2', title = 'Second', class = 'foot' },
  { mapped = true, workspace = { name = 'special:scratchpad', special = true }, focus_history_id = -1, address = '0x4', title = 'Scratchpad', class = 'foot' },
}

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
dofile('altswitch.lua')

local function press(key)
  local map = current_submap == '' and binds or submap_binds
  assert(map[key], key .. ' is not bound in submap "' .. current_submap .. '"')
  map[key]()
end

local function lastContains(text)
  assert(commands[#commands]:find(text, 1, true), commands[#commands])
end

press('CTRL + TAB')
lastContains('emil.altswitch show')
assert(not commands[#commands]:find('Scratchpad', 1, true))
-- Holding Ctrl changes only the selection, even across workspace boundaries.
press('CTRL + TAB')
lastContains("select '2'")
press('CTRL + TAB')
lastContains("select '0'")
press('CTRL + SHIFT + TAB')
lastContains("select '2'")
for _, command in ipairs(commands) do
  assert(not command:find('hyprctl dispatch', 1, true))
end
-- Alt release must not activate a Ctrl+Tab selection.
local count = #commands
events['input.keyboard.key'](64, nil, 0)
assert(#commands == count)
events['input.keyboard.key'](37, nil, 0)
lastContains('address:0x3')

press('CTRL + TAB')
events['input.keyboard.key'](105, nil, 0)
lastContains('address:0x2')

press('CTRL + TAB')
press('CTRL + ESCAPE')
lastContains('emil.altswitch hide')
count = #commands
events['input.keyboard.key'](37, nil, 0)
assert(#commands == count)

press('CTRL + TAB')
__emil_altswitch_cancel()
lastContains('emil.altswitch hide')
count = #commands
events['input.keyboard.key'](37, nil, 0)
assert(#commands == count)

windows = { windows[2] }
count = #commands
press('CTRL + TAB')
assert(#commands == count)

-- The region picker creates one layer per monitor. Its final cleanup removes
-- all Ctrl+Tab bindings, including ours, before our layer.closed callback runs.
local forward = binds['CTRL + TAB']
events['layer.closed']({ namespace = 'selection' })
events['layer.opened']({ namespace = 'unrelated' })
events['layer.closed']({ namespace = 'unrelated' })
assert(binds['CTRL + TAB'] == forward)
for cycle = 1, 3 do
  events['layer.opened']({ namespace = 'selection' })
  events['layer.opened']({ namespace = 'selection' })
  local picker = function() end
  binds['CTRL + TAB'] = picker
  events['layer.closed']({ namespace = 'selection' })
  assert(binds['CTRL + TAB'] == picker)
  hl.unbind('CTRL + TAB')
  events['layer.closed']({ namespace = 'selection' })
  assert(type(binds['CTRL + TAB']) == 'function')
  assert(type(submap_binds['CTRL + TAB']) == 'function')
end
windows[2] = { mapped = true, workspace = { name = '1', special = false }, focus_history_id = 1, address = '0x5', title = 'After capture', class = 'foot' }
press('CTRL + TAB')
lastContains('emil.altswitch show')
events['input.keyboard.key'](37, nil, 0)
lastContains('address:0x5')
assert(current_submap == '')

-- Clicking a tile commits that window right away, without waiting for Ctrl.
press('CTRL + TAB')
assert(current_submap == 'emil-altswitch')
__emil_altswitch_activate(5)
assert(current_submap == 'emil-altswitch', 'an out-of-range click is ignored')
__emil_altswitch_activate(0)
lastContains('address:0x1')
assert(current_submap == '')
count = #commands
events['input.keyboard.key'](37, nil, 0)
__emil_altswitch_activate(0)
assert(#commands == count, 'a stale click or release must not switch again')
print('Window ordering, cycling, Ctrl release, cancellation, single-window, picker cleanup, and click checks passed')
