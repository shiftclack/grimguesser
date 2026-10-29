# AGENTS.md file

Grim Guesser is an addon for _World of Warcraft Classic Hardcore_. It's developed in World of Warcraft Lua 5.1. The addon is intended for official WoW Hardcore Classic realms. It does not support Retail WoW.

## Additional Documentation

* [game.md](docs/game.md) documents game rules. Refer here when you need more information about game rules or scoring
* [ui.md](docs/ui.md) documents the UI. Refer here for information on how the UI should look and behave

## Common commands

The `Makefile` should wrap all common commands used by the human developer and coding agent.

- `make check` runs all checks
- `make coverage-summary` prints out the `luacov` code coverage summary
- `make install` installs the addon files to a local Windows WoW installation.
- `make dist`, `make dist-ci`, and `make dist-docker` build a zipfile for distribution

Note: The `*-ci` targets are used for building in CI/UNIX.

## Repo layout

### Directories

- `src/` addon source
- `tests/` test harness and suites
- `docs/` addon documentation
- `libs/` vendored third-party code (do not test, lint, or modify)
- `dist/` build output
- `types/` LuaLS type stubs
- `scripts/` helper scripts
- `data/` is reserved for local data processing

### Module naming

- `GrimController.lua` is the thin controller. WoW events and slash commands come in; model calls and UI refreshes go out.
- `GrimLogic*` and `GrimDatabase` are the model layer
- `GrimUI*` files are the view layer. They read model state through model APIs and update widgets, but should not directly modify the database state, sort model collections, or implement gameplay rules.

### Support files

- `Makefile` should contain reusable commands for building, testing and static analysis. It should be compatible with Windows systems for development and Linux for CI
- `.luacheckrc` should contain our `luacheck` configuration. Keep changes focused and only update it when project lint rules or recognized WoW globals genuinely need to change
- `.luarc.json` should contain the LuaLS configuration. Both `.luacheckrc` and `.luarc.json` will need to be configured when referencing new globals or WoW specific functions
- `src/GrimGuesser_Vanilla.toc` when adding new addon files, they must be added here in order for the game to load them. Order is important.

## Development

Small single-author project: work happens on feature branches off `main`,
squash-merged by the maintainer. Agents do not open pull requests, and do not merge or
push to `main`. Commit messages are short and lowercase (see `git log`).

## Lua

### Environments

There are three environments we develop for:
- WoW Lua 5.1 in-game (where we ship code)
- Windows running Lua 5.1 for local development/debugging
- Linux running Lua 5.1 for testing/building in GitHub Actions CI

### Compatibility

- Do not attempt to be forward-compatible with newer versions of Lua
- Do not add shims for backward compatibility without explicit instructions
- Only use Blizzard APIs that are available to Classic-era addons
- Do not invent APIs or assume Retail-only helpers exist in Classic
- If the test system doesn't have a particular function available, then mock it. Do not pollute production code with guards for the tests!
- If a Blizzard/WoW API is valid in Classic but tooling flags it as an undefined global, prefer updating `.luacheckrc` and `.luarc.json` over adding local aliases or other production-code workarounds just to satisfy tooling

### Parsing behavior

The death feed parser is intentionally conservative. The addon listens only to `CHAT_MSG_CHANNEL` messages from the `hardcoredeaths` channel and parses Blizzard death announcement text plus localized Blizzard `HARDCORE_CAUSEOFDEATH_*` format strings. Do not, under any circumstances, communicate with or parse data from other addons.

### Use of third party libraries

No third-party libraries or addons are to be used in production code, with the sole exception of libraries used for minimap integration in `src/GrimUIMinimap.lua`:
  - LibDBIcon
  - LibDataBroker
  - CallbackHandler
  - LibStub

### Nil-check contracts

- Keep `nil` guards at real boundaries: WoW event handlers, slash commands, SavedVariables/database normalization, and UI scripts that can legitimately fire before state is bound
- Inside a module, prefer explicit helper contracts over repeated defensive checks
- Avoid writing the same code path to accept multiple internal shapes unless that flexibility is required by a real public caller

### LuaLS annotations

- LuaLS is used to provide type checking via annotations
- Warnings are surfaced both in the editor UI and as part of `make check`
- When adding new functions, add LuaLS style `---@param` and `---@return` comments to specify types
- Check for existing types before adding new ones, especially for files with similar names like `src/GrimUI*.lua` or `src/GrimLogic*.lua`.
- Prefer being strict about parameters, it helps future developers reason about the codebase

### WoW vs Standard Lua

World of Warcraft uses a restricted Lua 5.1 runtime with significant differences from standard Lua:

- **Sandboxed and API-limited**  
  Only Blizzard-provided APIs are available. Many standard Lua libraries are partially or fully unavailable.

- **No dynamic module loading**  
  Functions like `require`, `dofile`, and `loadfile` are not available. All addon code must be loaded statically via the `.toc` file in a fixed order.

- **No filesystem or OS access**  
  Lua in WoW cannot read or write arbitrary files, execute shell commands, or access system libraries. `os.*` and `io.*` are not available.

- **No `package` system**  
  The standard Lua module system (`package.path`, `package.loaders`, etc.) is absent.

- **No `debug`**
  The `debug.*` functions are not available in WoW Lua.

- **Addon namespace**  
  WoW loads addon files into a shared global environment and provides each file with a shared namespace table. Use it to avoid creating globals (`local _, ns = ...`).

- **Event-driven execution model**  
  Code runs in response to Blizzard API events (e.g., `CHAT_MSG_CHANNEL`) rather than a traditional main loop.

- **Static load order is authoritative**  
  Dependency ordering must be handled manually via the `.toc` file. There is no runtime dependency resolution.

### Selected extra WoW Lua functions

- `wipe()` is like setting `table={}`, except that it keeps the variable's internal pointer
- `date()` is a reference to the Lua `os.date` function
- `time()` is a reference to the Lua `os.time` function

## Static analysis

- Linting is provided by `luacheck` (`make lint`)
- Use `lua-language-server` to check our LuaLS/EmmyLua annotations (`make luals`)
- When running into issues with `make check` around globals, check both `.luacheckrc` and `.luarc.json`

## Testing

### Test plumbing

- Do not add defensive branches for missing WoW globals only for the tests
- Do not add default values to production code only for the tests
- Prefer mocking Blizzard APIs in the test harness over checking for their availability in production code

### Test expectations

***After you make changes, always run `make check`.***

- If you fix a bug in parser or scoring behavior, add or update a test when practical
- Prefer unit tests for parser and logic behavior over manual-only verification
- Run tests with Busted under Lua 5.1 through `make test`. Use `TEST_ARGS` for file paths, filters, or shuffle options.

## Datastores

### SavedVariables

SavedVariables is how WoW persists user configuration and data for the addon.

- Treat `GrimCharacterState` as per-character persistent user data
- When adding fields, initialize missing values defensively in `GrimDatabase`
- Do not require users to delete SavedVariables for normal addon updates
- Prefer additive schema changes over breaking renames
- Other modules should use the `GrimDatabase` public functions to access data, as they enforce necessary data validation safeguards

### Migrations

- In `src/GrimMigration.lua` we have a set of migrations for SavedVariables
