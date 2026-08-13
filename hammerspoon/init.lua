-- Hammerspoon exists here for exactly one binding.
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

hs.hotkey.bind({ "shift" }, "f18", function()
  hs.hid.capslock.toggle()
end)
