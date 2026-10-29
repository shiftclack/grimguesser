# ui.md

The UI for Grim Guesser follows standard game conventions for simplicity and performance.

## UI constraints

- Use built-in game UI elements
- Try to keep the same look and feel as the classic game UI
- Keep the main window draggable and simple
- Preserve the split between recent death history and prediction controls
- Favor clear and legible controls over flashy behavior
- Keep visibility controls available through slash commands

## Colors

Across the UI we want to map anything displaying points (like the death log lines)
to the item colors in wow: orange, purple, blue, green, white, gray. 

## Prediction UI Window

The main window is how the user primarily interacts with the addon. It's a draggable UI window with a title of GRIM GUESSER. The top pane displays a list of the most recent deaths, including various elements about the death. The lower pane of the window can be used by the user to perform input for predictions.

- Top part of window is a list of recent deaths sorted by time, newest at the bottom
    - Show the last 5 deaths
    - Columns: Time, Source, Level, Location, Points
- Bottom part of the window is the "Prediction" Section
    - Allows the user to interact with the points system
- At the bottom of the window are buttons
    - The "LOCK IN" button will finalize the prediction
    - The "PAUSE" button will pause prediction (and thus stop gaining points)
    - The "LOG" button will show an optional death log
    - The "HELP" button will open the help window

Schematic layout (example death rows and score values):

```text
+-- GRIM GUESSER ------------------------------------------------------+
| Time   Source               Level  Location                  Points  |
| 10:03  Kobold                   6  Elwynn Forest                  0  |
| 10:04  Defias Bandit           12  Westfall                      10  |
| 10:05  Defias Bandit           12  Westfall                      10  |
+----------------------------------------------------------------------+
|         Longest streak: 12   Current streak: 3   Score: 110          |
|                                                                      |
| Prediction                                                           |
|                                                                      |
| Level range:  [10-19] [20-29] [30-39] [40-49] [50-59] [60]           |
|                                                                      |
| Source:       [autocomplete text field]                              |
|                                                                      |
| Location:     [autocomplete text field]                              |
|                                                                      |
| Current prediction:                                                  |
| (Prediction summary)                                                 |
|                                                                      |
|               [HELP]    [LOG]    [PAUSE]    [LOCK IN]                |
+----------------------------------------------------------------------+
```

### Source Details

- The "Source" is an autocompleting text field with a suggestion dropdown
- The player can select from an alphabetical list combining popular dangerous sources with sources
  found in the retained death history, or specify their own

### Zone (Location) Details

- The `zone` is called `location` in the UI
- The `location` has an autocompleting text field with a suggestion dropdown
- The addon uses an alphabetical list combining default zones with locations found in the retained death history
- The user can also input their own zones

## Collapsed Prediction UI Window

There is also a collapsed version of the prediction UI window.

It is a smaller window activated via a button in the title bar. This smaller version of the UI suitable to show even while a player is adventuring in dangerous areas. For that reason, we must not add anything to the collapsed window that might kill the player.

In addition, when the collapsed window is open, all other addon windows should be closed (except for non-game windows like the debug window).

- The collapsed window keeps a fixed width
- The player may shrink its height to show fewer recent deaths, down to 1 visible row
- The collapsed view still shows at most 5 recent deaths
- Columns: Time, Source, Level, Location, Points

## Log Window

The log window provides the user with a log of recent deaths. It is the "Historical Death Log".

- The title of the window is "LOG"
- It has buttons to toggle between a list of successful predictions and all deaths
- It's its own window, to the right of the Prediction UI window
- It's the same height as the prediction ui window
- It can be opened and closed independently
- By default it is closed
- The window automatically closes when the prediction window is minimized, and assumes the previous state of shown/hidden when it is maximized. This way it is always hidden when the window is small, and it remembers the users preference to keep it open or not
- The window is as small as possible horizontally, while still being able to show all columns in its scrollable list

It contains a scrollable list with the following columns:

- Time (replaced by Rank when showing successful predictions only)
- Source
- Points

## Help Window

- The help window provides information to the user
- It should summarize the game rules at a high level
- It should also include information on how to configure the game to work with the addon
- It should include a download link to the GitHub releases
- The GitHub link opens a centered modal dialog with a selectable, editable URL field for copy/paste in the WoW UI
- Do not update the help text automatically without specific instructions

## Minimap Icon

There is a clickable minimap icon that the user can use to toggle open/closed the module's windows.
The `/grimguesser minimap` command and the "Disable minimap icon" configuration option toggle whether
the icon is shown, and it is enabled by default.

## Command line

The addon exposes core functionality through slash commands ("/-commands"). This includes:

- A `/grimguesser help` command that explains the other commands
- Commands for opening and closing each window
- Commands to enable/disable features
- Commands for debugging

## Debug Window

- There is also a Debug window that can be used to help debug the addon. 
- Debug mode is disabled by default. 
- The "/grimguesser debug" command toggles a session-only debug flag for the addon. When enabled, it both shows the Debug window and allows debug messages to be printed. When disabled, it hides the Debug window and suppresses debug prints.

_Copyright © 2026 Shiftclack. Licensed under the PolyForm Strict License 1.0.0; see [LICENSE.md](https://github.com/shiftclack/grimguesser/blob/main/LICENSE.md)._
