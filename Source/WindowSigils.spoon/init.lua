--- === WindowSigils ===
---
--- Assign every window and empty rectangle a sigil for quick access.
---
--- A letter or digit is rendered in the titlebar of every window (or empty space), and
--- actions can be bound inside the sigil mode and triggered with different modifiers.
--- The `sigils` program finds the windows and empty spaces, hands out the sigils and draws
--- them, from a daemon it starts, so WindowSigils.sigilsCommand must be set to its path.
---
--- For example, with no modifiers, a sigil key can focus the window.  If the 'enter'
--- action is bound to control-w, then 'control-w c' will focus the window with sigil 'c'.
--- The action is a function which accepts a window, or in the case of an empty space, a
--- window-like object which reponds to 'id', 'frame', and 'setFrame'.
---
--- The keys 'h', 'j', 'k', and 'l' are reserved for the window west, south, north, and
--- east of the currently focused window in standard Vi-like fashion, and so are not
--- assigned as sigils.
---
--- By default, two keys (other than the sigils) are bound in the mode: escape leaves the
--- mode without doing anything, and '.' sends the sigil key to the focused window.  This
--- allows sending 'control-w' to the underlying window by typing 'control-w .'.
---
--- Download: [https://github.com/Hammerspoon/Spoons/raw/master/Spoons/WindowSigils.spoon.zip](https://github.com/Hammerspoon/Spoons/raw/master/Spoons/WindowSigils.spoon.zip)
---
--- Usage example:
--- ```
--- local function ignore_notification()
---   -- ...
--- end
--- local function paste_as_keystrokes()
---   hs.eventtap.keyStrokes(hs.pasteboard.readString())
--- end
--- local function rerun_last_command()
---   hs.execute("kitty @ --to unix:/Users/jfelice/.run/kitty send-text --match=title:kak_repl_window '\x10\x0d'", true)
--- end
---
--- local function focus_window(window)
---   window:focus()
---   if hs.window.focusedWindow() ~= window then
---     -- Some cases with apps having windows on multiple monitors require
---     -- us to try again (?)
---     window:focus()
---   end
--- end
---
--- local function swap_window(window)
---   local focused_frame = hs.window.focusedWindow():frame()
---   local selected_frame = window:frame()
---   hs.window.focusedWindow():setFrame(selected_frame, 0)
---   window:setFrame(focused_frame, 0)
--- end
---
--- local function stack_window(window)
---   local frame = window:frame()
---   hs.window.focusedWindow():setFrame(frame, 0)
--- end
---
--- sigils = hs.loadSpoon("WindowSigils")
--- sigils.sigilsCommand = "/run/current-system/sw/bin/sigils"
--- sigils:configure({
---   hotkeys = {
---     enter = {{"control"}, "W"}
---   },
---   mode_keys = {
---     [{{'shift'}, 'i'}] = ignore_notification,
---     [{{}, 'v'}]        = paste_as_keystrokes,
---     [{{}, ','}]        = rerun_last_command,
---   },
---   sigil_actions = {
---     [{}]       = focus_window,
---     [{'ctrl'}] = stack_window,
---     [{'alt'}]  = swap_window,
---   }
--- })
--- sigils:start()
--- ```

local EmptyWindow = dofile(hs.spoons.resourcePath("empty_window.lua"))

local obj={}
obj.__index = obj

-- Metadata
obj.name = "WindowSigils"
obj.version = "0.1"
obj.author = "Jason Felice <jason.m.felice@gmail.com>"
obj.homepage = "https://github.com/Hammerspoon/Spoons"
obj.license = "MIT - https://opensource.org/licenses/MIT"

--- WindowSigils.logger
--- Variable
--- Logger object used within the Spoon. Can be accessed to set the default log level for the messages coming from the Spoon.
obj.logger = hs.logger.new('WindowSigils')

obj.sigils = {
  "a", "b", "c", "d", "e", "f", "g", "i", "m", "n", "o", "p", "q", "r", "s", "t", "u",
  "v", "w", "x", "y", "z", ";", ",", "/", "0", "1", "2", "3", "4", "5", "6", "7",
  "8", "9",
}

--- WindowSigils.sigilsCommand
--- Variable
--- The path of the `sigils` program, which finds the windows and empty spaces and gives
--- them sigils, so they agree with anything else which asks it.
obj.sigilsCommand = nil

--- WindowSigils:bindHotkeys(mapping)
--- Method
--- Binds hotkeys for WindowSigils
---
--- Parameters:
---  * mapping - A table containing hotkey objifier/key details for the following items:
---   * enter - Enter the sigil mode
function obj:bindHotkeys(mapping)
  if mapping['enter'] then
    mods, key = table.unpack(mapping['enter'])
    self.mode = hs.hotkey.modal.new(mods, key)
    self.mode:bind({}, 'escape', function() self.mode:exit() end)
    self.mode:bind({}, '.', function()
      self.mode:exit()
      self.mode.k:disable()
      hs.eventtap.keyStroke(mods, key)
      self.mode.k:enable()
    end)
  end
end

--- WindowSigils:configure(configuration)
--- Method
--- Configures the spoon.
---
--- Parameters:
---  * configuration - :
---    * hotkeys -
---    * mode_keys - a table of key specs (e.g. {{'shift'}, 'n'}) to functions.  The keys are
---      mapped inside the sigil mode and the key is no longer used as a window sigil.
---    * sigil_actions - a table of mod specs (e.g. {'alt'}) to functions.  When the sigil is
---      used in the sigil mode with the specified modifier pressed, the function is invoked
---      with a window object.
function obj:configure(configuration)
  if configuration['hotkeys'] then
    self:bindHotkeys(configuration['hotkeys'])
  end
  if configuration['mode_keys'] then
    for keyspec,fn in pairs(configuration['mode_keys']) do
      local mods, key = table.unpack(keyspec)
      self:bindModeKey(mods, key, fn)
    end
  end
  if configuration['sigil_actions'] then
    for mods,fn in pairs(configuration['sigil_actions']) do
      self:bindSigilAction(mods, fn)
    end
  end
end

--- WindowSigils:bindModeKey(mods, key, action)
--- Method
--- Bind an extra action to be triggered by a key in the sigil mode.
---
--- Parameters:
---  * mods - The key modifiers
---  * key - The key
---  * action - A function, called with no parameters.
function obj:bindModeKey(mods, key, action)
  local sigil_to_remove = hs.fnutils.indexOf(self.sigils, key)
  if sigil_to_remove then
    table.remove(self.sigils, sigil_to_remove)
  end
  self.mode:bind(mods, key, function()
    self.mode:exit()
    action()
  end)
end

local directions = {
  h = 'West',
  j = 'South',
  k = 'North',
  l = 'East'
}

--- WindowSigils:bindSigilAction(mods, action)
--- Method
--- Bind an action to be triggered in the sigil mode when a window's sigil key is pressed.
---
--- Parameters:
---  * mods - The modifiers which must be held to trigger this action.
---  * action - A function which takes a window object and performs this action.
function obj:bindSigilAction(mods, action)
  local function make_action(sigil)
    return function()
      self.mode:exit()
      local window = self:window(sigil)
      if window then
        action(window)
      end
    end
  end
  for key,direction in pairs(directions) do
    self.mode:bind(mods, key, make_action(direction))
  end
  for _,sigil in ipairs(self.sigils) do
    self.mode:bind(mods, sigil, make_action(sigil))
  end
end

--- WindowSigils:start()
--- Method
--- Starts the `sigils` daemon, which draws the sigils, if it isn't running
---
--- Parameters:
---  * None
function obj:start()
  -- Only to find the hs.window objects for the sigils' window ids quickly.
  self.window_filter = hs.window.filter.new({override={
    visible = true,
  }}):setDefaultFilter({
    visible = true,
  })

  -- Asking starts the daemon, which draws the sigils, with this spoon's sigils and insets.
  self._sigilsTask = hs.task.new(self.sigilsCommand, function() self._sigilsTask = nil end,
                                 self:_sigilsArguments())
  self._sigilsTask:start()
end

--- WindowSigils:stop()
--- Method
--- Stops looking up windows.  The `sigils` daemon goes on drawing the sigils
---
--- Parameters:
---  * None
function obj:stop()
  if self._sigilsTask then
    self._sigilsTask:terminate()
  end
  self.window_filter = nil
end

--- WindowSigils.reservedInsets
--- Variable
--- Strips along the edges of every screen, in pixels, which are never offered
--- as empty space.  A table with any of the keys `top`, `bottom`, `left` and
--- `right`; for example `{ top = 36 }` for a status bar which is not a window.
obj.reservedInsets = {}

local function shell_quote(s)
  return "'" .. (s:gsub("'", "'\\''")) .. "'"
end

function obj:_sigilsArguments()
  local arguments = { "-s", table.concat(self.sigils) }
  local insets = {}
  for _, edge in ipairs({ "top", "bottom", "left", "right" }) do
    if self.reservedInsets[edge] then
      table.insert(insets, edge .. "=" .. self.reservedInsets[edge])
    end
  end
  if #insets > 0 then
    table.insert(arguments, "-i")
    table.insert(arguments, table.concat(insets, ","))
  end
  return arguments
end

function obj:_listSigils()
  local command = shell_quote(self.sigilsCommand)
  for _, argument in ipairs(self:_sigilsArguments()) do
    command = command .. " " .. shell_quote(argument)
  end
  local output, ok = hs.execute(command)
  if not ok then
    self.logger.e("sigils failed")
    return ""
  end
  return output
end

-- The windows and empty spaces listed by `sigils`, so that the nth one has the
-- nth sigil.
function obj:_windowsFromListing(listing)
  local known = {}
  for _, window in ipairs(self.window_filter:getWindows()) do
    known[window:id()] = window
  end
  local windows = {}
  for line in listing:gmatch("[^\n]+") do
    local id, x, y, w, h = line:match("^%S (%d+) (%-?%d+) (%-?%d+) (%d+) (%d+) ")
    if id then
      id = tonumber(id)
      local frame = hs.geometry.rect(tonumber(x), tonumber(y), tonumber(w), tonumber(h))
      local window = id ~= 0 and (known[id] or hs.window.get(id))
      table.insert(windows, window or EmptyWindow:new(frame))
    end
  end
  return windows
end

--- WindowSigils:orderedWindows()
--- Method
--- A list of windows, in the order sigils are assigned.
---
--- Parameters:
---  * None
function obj:orderedWindows()
  return self:_windowsFromListing(self:_listSigils())
end

--- WindowSigils:window(sigil)
--- Method
--- Find the window with the given index or sigil.
---
--- Parameters:
---  * sigil - If a number, the index of the window; if a string, the sigil of the window.
---    Can also be 'North', 'East', 'South', or 'West' to find a window related to the
---    currently focused window.
function obj:window(sigil)
  local windows = self:orderedWindows()
  if type(sigil) == 'number' then
    return windows[sigil]
  elseif sigil == 'North' then
    return hs.window.focusedWindow():windowsToNorth(windows, true, true)[1]
  elseif sigil == 'East' then
    return hs.window.focusedWindow():windowsToEast(windows, true, true)[1]
  elseif sigil == 'South' then
    return hs.window.focusedWindow():windowsToSouth(windows, true, true)[1]
  elseif sigil == 'West' then
    return hs.window.focusedWindow():windowsToWest(windows, true, true)[1]
  else
    for i,k in ipairs(self.sigils) do
      if k == sigil then
        return windows[i]
      end
    end
  end
  return nil
end


function obj:dump()
  local result = ""
  for i, window in ipairs(self:orderedWindows()) do
    local app = window:application()
    local bundleID = "<no app>"
    if app ~= nil then
      bundleID = app:bundleID()
    end
    local frame = window:frame()
    result = string.format("%s %s) %5.0f,%5.0f,%5.0f,%5.0f  %-35s %s\n", result, self.sigils[i],
                           frame.x1, frame.y1, frame.x2, frame.y2,
                           bundleID, window:title())
  end
  return result
end

return obj
