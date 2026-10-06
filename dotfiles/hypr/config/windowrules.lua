hl.window_rule({
    match = { class = "^(pavucontrol|nm-connection-editor|blueman-manager)$" },
    float = true,
    center = true,
    size = { 900, 600 },
})

hl.window_rule({
    match = { class = "^(zenity|Zenity|org\\.gnome\\.Zenity|kdialog)$" },
    float = true,
    center = true,
    size = { 900, 600 },
})

hl.window_rule({
    match = { title = "^(Picture-in-Picture|Open File|Save File)$" },
    float = true,
})

hl.window_rule({
    match = { class = "^(Alacritty|kitty)$" },
    opacity = "0.96 override 0.96 override",
})

hl.window_rule({
    match = { class = "^(thunar|Thunar)$" },
    opacity = "1.0 override 1.0 override",
    rounding = 14,
    border_size = 0,
})

hl.window_rule({
    match = { class = ".*" },
    suppress_event = "maximize",
    no_max_size = true,
})
