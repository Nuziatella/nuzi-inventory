local Constants = {}

Constants.ADDON = {
    name = "Nuzi Inventory",
    author = "Nuzi",
    version = "2.0.1",
    desc = "Search bag, bank, alt, and tracked items across your roster"
}

Constants.ADDON_ID = "nuzi-inventory"
Constants.WINDOW_ID = "nuziInventoryWindow"
Constants.BUTTON_ID = "nuziInventoryButton"
Constants.EVENT_WINDOW_ID = "nuziInventoryEvents"
Constants.SETTINGS_FILE_PATH = "nuzi-inventory/.data/settings.txt"
Constants.LEGACY_SETTINGS_FILE_PATHS = {
    "nuzi-inventory/settings.txt",
    "nuzi-bagsearch/.data/settings.txt",
    "nuzi-bagsearch/settings.txt"
}
Constants.ICON_PATH = "nuzi-inventory/icon.png"
Constants.ROWS_PER_PAGE = 12
Constants.HOTBAR_DEFAULT_X = 280
Constants.HOTBAR_DEFAULT_Y = 140
Constants.HOTBAR_USE_OFFSET_Y = 64
Constants.TRACKED_POLL_INTERVAL_MS = 1000

Constants.DEFAULT_SETTINGS = {
    button_x = 156,
    button_y = 140,
    window_x = 210,
    window_y = 160,
    hotbar_x = Constants.HOTBAR_DEFAULT_X,
    hotbar_y = Constants.HOTBAR_DEFAULT_Y,
    use_hotbar_x = Constants.HOTBAR_DEFAULT_X,
    use_hotbar_y = Constants.HOTBAR_DEFAULT_Y + Constants.HOTBAR_USE_OFFSET_Y,
    tracked_bar_positions = {},
    tracked_group_mode = "two_bars",
    tracked_icons_per_row = 8,
    query = "",
    include_bank = true,
    page = 1,
    saved_characters = {},
    tracked_items = {}
}

return Constants

