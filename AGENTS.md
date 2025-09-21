# Repository Guidelines

## Project Structure & Module Organization
`build.zig` defines all targets and links GTK via pkg-config. Place application source in `src/`, grouping widgets and helpers under `src/ui/` and `src/core/`. Shared Zig packages belong in `libs/`, while experimental demos live in `examples/` so they can be compiled independently. Keep test-specific fixtures in `tests/data/` to avoid shipping them with release builds.

## Build, Test, and Development Commands
- `zig build`: default debug build; rerun after changing dependencies to refresh generated bindings.
- `zig build run`: builds then launches the GTK demo defined by the `run` step in `build.zig`.
- `zig build -Drelease-safe`: produces an optimized binary used for packaging.
- `zig build test`: executes all Zig `test` blocks and verifies GTK integration stubs.
Use `zig fmt src tests examples` before committing to ensure consistent formatting.

## Coding Style & Naming Conventions
Follow Zig defaults: four-space indentation, no tabs, and rely on `zig fmt`. Functions and variables use `camelCase`; types, errors, and namespaces use `TitleCase`; constants use `SCREAMING_SNAKE`. Keep module files focused—split large widgets into separate files under `src/ui/`. Prefer explicit error unions and document unsafe GTK calls with a brief comment describing the lifetime expectations.

## Testing Guidelines
Place unit tests alongside implementation files using Zig `test` blocks and name them after the behavior, e.g., `test "button click updates label"`. Integration tests targeting multiple modules belong in `tests/` using helper runners under `tests/runner.zig`. Aim to cover all public APIs and any GTK signal wiring. Run `zig build test` locally before opening a PR, and include reproduction cases for any GTK regression you fix.

## Commit & Pull Request Guidelines
Adopt Conventional Commits (`feat:`, `fix:`, `chore:`) to keep the history scannable, e.g., `feat: add preferences dialog shell`. Squash work-in-progress commits before pushing. Pull requests should describe the GTK feature or bug addressed, list manual test steps (`zig build run` on the relevant demo), and link to open issues. Attach screenshots or recordings when UI changes are visible.

## GTK Integration Notes
Ensure GTK development headers are installed (`sudo apt install libgtk-4-dev` or equivalent) so pkg-config can resolve includes. When adding new C libraries, update `build.zig` to propagate search paths and verify with `pkg-config --libs gtk4`. Keep environment-specific tweaks isolated in `config/` and document any required env vars in the PR description.
