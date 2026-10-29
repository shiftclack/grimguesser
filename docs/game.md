# game.md

Documentation for the GRIM GUESSER game rules.

## Goal

The goal of the game is to accumulate as many points as possible from the deaths of other players before the user themselves dies.

## Definitions

- `User`: the user of the addon
- `Player`: someone playing wow, either as another character or the user
- `Death`: a player death in WoW Classic Hardcore
- `Active death`: This is the most recent received death
- `Accepted death`: This is a death that has passed all validation and is considered genuine
- `Prediction`: a guess made by the user about upcoming player deaths
- `Prediction element`: one element of a potentially multi-element prediction, such as a zone, level or source
- `Draft prediction`: the prediction currently being edited in the UI
- `Successful prediction`: a prediction where at least one selected element matches the accepted death
- `Failed prediction`: a prediction that did not match the active death
- `Points`: these are awarded for successful predictions
- `Multiplier`: a factor applied to the matched base points, such as x0, x5, x10
- `Streak`: successive correct predictions grant a points multiplier
- `Current streak`: the current run of consecutive matched predictions
- `Longest streak`: the highest current-streak value reached so far
- `Score`: the sum of a user's points
- `Source`: the cause of death, for example a mob like "Hogger" or "Falling"
- `Zone`: the WoW zone associated with the death. The UI may refer to this informally as the death's `location`
- `Locked in`: When the user hits the "LOCK IN" button, they are signaling their prediction is finalized

## Modes

- `Attract mode`: When the addon starts for the first time, it is in `attract mode`. In this mode a demo of incoming deaths and scoring is displayed
- `Intro mode`: When the user is inputting their first prediction and has not locked in yet
- `Live mode`: When the addon is running and the player is able to receive points or change their existing prediction

## Predictions

- A prediction can include any subset of `level range`, `source`, and `location`
- The user does not need to fill every field for a prediction to be valid
- A locked prediction applies to accepted deaths that arrive after the lock-in action

## Matching

- The player is awarded points based on successful matching
- Matching is evaluated separately for each selected prediction element
- A partial match still counts as a matched prediction
- A perfect match requires every selected element to match

## Scoring

### Configuration

- Scoring is controlled by configured constants in `GrimConstants.lua`
- Scoring is kept configurable to support easy tuning of the game

### Points

- Players are awarded points when their locked in prediction matches the accepted death
- Each matched prediction element contributes its configured base points to the score

### Level predictions

- Level predictions use configured level buckets and configured point values
- Users are awarded a fixed amount of base points for a correct level prediction

### Location prediction

- Location predictions match on the `location` associated with an accepted death
- The `location` is often, but not always, the zone of the death
- A successful location prediction awards a fixed amount of points

### Source prediction

- Source predictions match on what the proximal cause is for an accepted death
- This is either the name of a mob or an environmental source like falling or drowning
- A successful source prediction awards a fixed amount of points

### Multipliers

- A matched prediction with multiple correct prediction elements awards a multiplier (combo)
- The more elements that are concurrently predicted correctly, the higher the combo bonus.
- Multipliers are notated in the form `xN` where `N` is an integer. `x2` means multiply the points by 2, and `x4` means multiply the points by 4
- Multipliers are additive: `x2` and `x4` add to a `x6` multiplier

### Streaks

- Any matched prediction advances the streak, including partial wins
- A miss resets the current streak
- A death with no locked prediction also resets the current streak
- Locking in a different prediction resets the current streak
- Re-locking the same prediction does not reset the current streak
- Streaks award a multiplier which grows with each successive successful prediction

### Bonuses

- The `same-zone bonus` grants additional points if the zone of the death is the same as the user's current zone.

_Copyright © 2026 Shiftclack. Licensed under the PolyForm Strict License 1.0.0; see [LICENSE.md](https://github.com/shiftclack/grimguesser/blob/main/LICENSE.md)._
