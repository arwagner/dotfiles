-- Hammerspoon exists here for a Caps Lock binding and a sketchybar workaround.
--
-- Karabiner turns Caps Lock into f18 on every keyboard, unconditionally, and it
-- passes Shift through untouched, so Shift-CapsLock arrives here as Shift-f18.
-- That is the only way back to a real Caps Lock, which is why this file stays
-- even though the leader tree it used to load is gone.
--
-- hs.hid talks to the HID layer directly rather than through the normal key
-- path, so watch whether the external keyboard's LED keeps up.
--
-- Bare f18 is unbound: pressing Caps Lock alone does nothing.

-- Opens the message port the `hs` CLI talks to, so the running config can be
-- inspected from a shell. Hammerspoon logs nowhere else: its console is the
-- only place errors surface, and nothing reaches the system log.
require("hs.ipc")

hs.hotkey.bind({ "shift" }, "f18", function()
  hs.hid.capslock.toggle()
end)

-- The menu bar auto-hides so sketchybar can own the top of the screen. When it
-- drops back down it lands on top of sketchybar -- the menu bar draws at a
-- window level nothing else reaches -- and as of macOS 26 it has no background
-- of its own, so its white text falls straight onto sketchybar's white icons
-- and labels and neither one is readable. Accessibility's "reduce
-- transparency" does not help: the new menu bar is transparent by design
-- rather than by material.
--
-- So take sketchybar away for as long as the menu bar is down. The menu bar
-- then renders over the desktop, which is the one case macOS still tints its
-- text for.

local SKETCHYBAR = "/opt/homebrew/bin/sketchybar"

-- The menu bar reveals only when the pointer touches the very top edge, but it
-- stays down the whole time the pointer is over it. Restoring at the same edge
-- would flap the bar the instant it hid, so restore lower down: 40 is
-- sketchybar's own height, which clears the tallest menu bar (the notched
-- built-in display's). Between the two the bar keeps whatever state it has.
local REVEAL_AT = 1
local RESTORE_BELOW = 40

local hidden = false

local function setBar(hide)
  if hide == hidden then
    return
  end
  hidden = hide
  -- Asynchronous on purpose. This runs inside the event tap below, which every
  -- mouse movement passes through, and spawning a process synchronously there
  -- would stutter the pointer.
  hs.task.new(SKETCHYBAR, nil, { "--bar", hide and "hidden=on" or "hidden=off" }):start()
end

-- Global, not local: Hammerspoon collects an event tap that nothing holds a
-- reference to, and a collected tap stops firing.
menuBarPeek = hs.eventtap.new({
  hs.eventtap.event.types.mouseMoved,
  -- Dragging a window up to the top sends drag events instead of moves, and
  -- reveals the menu bar just the same.
  hs.eventtap.event.types.leftMouseDragged,
}, function()
  local screen = hs.mouse.getCurrentScreen()
  if not screen then
    return
  end

  -- Measured from the top of whichever screen the pointer is on, since that is
  -- the screen the menu bar drops onto.
  local y = hs.mouse.absolutePosition().y - screen:fullFrame().y

  if y <= REVEAL_AT then
    setBar(true)
  elseif y > RESTORE_BELOW then
    setBar(false)
  end
end)

menuBarPeek:start()
