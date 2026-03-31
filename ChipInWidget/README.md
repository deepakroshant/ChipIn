# ChipInWidget

WidgetKit extension for Chip In.

## Setup in Xcode

1. File → New → Target → Widget Extension
2. Product Name: `ChipInWidget`
3. Uncheck "Include Configuration App Intent"
4. Replace generated files with `ChipInWidget.swift`

## App Group Setup (Required for data sharing)

Both the main app and widget must share an App Group:

1. Main app target → Signing & Capabilities → + App Groups → `group.com.yourname.chipin`
2. Widget target → same App Group

## How It Works

- `HomeViewModel` writes `netBalance` to the shared `UserDefaults` App Group
- `WidgetCenter.shared.reloadAllTimelines()` triggers widget refresh
- Widget reads the value and displays it
