# Hyprland Configuration for Rice Studio

To make Rice Studio always start as a floating window in Hyprland, add the following rule to your `~/.config/hypr/hyprland.conf`:

```conf
# Rice Studio - Float by default
windowrulev2 = float, class:^(com.lianli.fancontrol)$
windowrulev2 = size 1200 800, class:^(com.lianli.fancontrol)$
windowrulev2 = center, class:^(com.lianli.fancontrol)$
```

## What this does:

- `float` - Makes the window float instead of tile
- `size 1200 800` - Sets the default window size to 1200x800 pixels
- `center` - Centers the window on the screen when it opens

## Finding the window class

If the above doesn't work, you can find the actual window class by:

1. Run Rice Studio: `./rice`
2. While it's running, open a terminal and run: `hyprctl clients | grep -A 10 "Rice Studio"`
3. Look for the `class:` field
4. Update the window rule with the correct class name

## Applying changes

After editing `hyprland.conf`, reload Hyprland:
```bash
hyprctl reload
```

Or use the keybind (usually `Super + Shift + R` or similar depending on your config).
