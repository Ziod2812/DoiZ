local namespaces = {
    "waybar",
    "^doiz[-_]",
}

for _, namespace in ipairs(namespaces) do
    hl.layer_rule({
        match = { namespace = namespace },
        ignore_alpha = 0,
    })
end
