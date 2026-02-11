-- Luacheck configuration for F3L Lua Training Script

-- Global variables that are provided by EdgeTX/OpenTX
globals = {
    -- EdgeTX/OpenTX API
    "model",
    "getTime",
    "getValue",
    "playTone",
    "playFile",
    "playDuration",
    "playNumber",
    "lcd",
    "rfState",
    -- Constants
    "PLAY_BACKGROUND",
    "EVT_EXIT_BREAK",
    "EVT_ENTER_BREAK",
    "MIDSIZE",
    "SMLSIZE",
}

-- Ignore specific issues for this project
ignore = {
    "212",  -- unused argument
    "311",  -- value assigned to a local variable is unused
}

-- Configure max line length
max_line_length = 120

-- Configure indentation
indent_type = "space"
indent_size = 2
