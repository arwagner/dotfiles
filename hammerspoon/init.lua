-- Hammerspoon's entry point. The leader key is bound here. The tree it opens
-- lives in home.toml beside this file.
--
-- Karabiner turns Caps Lock into f18 on every keyboard, so f18 is the leader.
-- Neither keyboard has a physical F18 and macOS binds nothing to it, so the
-- key arrives here unclaimed.
--
-- Hammerflow itself is not tracked in this repo. bin/install clones it into
-- Spoons/ and pulls it on each run, so it tracks upstream main.

hs.loadSpoon("Hammerflow")
spoon.Hammerflow.loadFirstValidTomlFile({ "home.toml" })

-- Caps Lock still has to be Caps Lock sometimes. Karabiner rewrites the key
-- itself and passes Shift through untouched, so Shift-CapsLock arrives as
-- Shift-f18. hs.hid talks to the HID layer directly rather than through the
-- normal key path, so watch whether the external keyboard's LED keeps up.
hs.hotkey.bind({ "shift" }, "f18", function()
  hs.hid.capslock.toggle()
end)
