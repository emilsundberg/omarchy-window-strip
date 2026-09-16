local binds, events, commands = {}, {}, {}
local windows = {
  { mapped = true, workspace = { name = '2', special = false }, focus_history_id = 2, address = '0x3', title = 'Third', class = 'foot' },
  { mapped = true, workspace = { name = '1', special = false }, focus_history_id = 0, address = '0x1', title = 'First', class = 'chromium' },
  { mapped = true, workspace = { name = '1', special = false }, focus_history_id = 1, address = '0x2', title = 'Second', class = 'foot' },
  { mapped = true, workspace = { name = 'special:scratchpad', special = true }, focus_history_id = -1, address = '0x4', title = 'Scratchpad', class = 'foot' },
}

hl = {
  unbind = function(key) binds[key] = nil end,
  bind = function(key, callback) binds[key] = callback end,
  on = function(event, callback) events[event] = callback end,
  exec_cmd = function(command) commands[#commands + 1] = command end,
  get_windows = function() return windows end,
  layer_rule = function() end,
}
dofile('altswitch.lua')

local function lastContains(text)
  assert(commands[#commands]:find(text, 1, true), commands[#commands])
end

binds['CTRL + TAB']()
lastContains('emil.altswitch show')
assert(not commands[#commands]:find('Scratchpad', 1, true))
-- Holding Ctrl changes only the selection, even across workspace boundaries.
binds['CTRL + TAB']()
lastContains("select '2'")
binds['CTRL + TAB']()
lastContains("select '0'")
binds['CTRL + SHIFT + TAB']()
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

binds['CTRL + TAB']()
events['input.keyboard.key'](105, nil, 0)
lastContains('address:0x2')

binds['CTRL + TAB']()
binds['CTRL + ESCAPE']()
lastContains('emil.altswitch hide')
count = #commands
events['input.keyboard.key'](37, nil, 0)
assert(#commands == count)

binds['CTRL + TAB']()
__emil_altswitch_cancel()
lastContains('emil.altswitch hide')
count = #commands
events['input.keyboard.key'](37, nil, 0)
assert(#commands == count)

windows = { windows[2] }
count = #commands
binds['CTRL + TAB']()
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
end
windows[2] = { mapped = true, workspace = { name = '1', special = false }, focus_history_id = 1, address = '0x5', title = 'After capture', class = 'foot' }
binds['CTRL + TAB']()
lastContains('emil.altswitch show')
events['input.keyboard.key'](37, nil, 0)
lastContains('address:0x5')
print('Window ordering, cycling, Ctrl release, cancellation, single-window, and picker cleanup checks passed')
