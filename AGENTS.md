# AGENTS.md

## App Overview

- The app fetches show and episode data from an external API.
- In product terms, a show can be marked as "watching". In the current codebase, that state is represented as a bookmarked series.
- A show can have an associated download folder even if it is not marked as watching. Folder mappings are separate from the bookmarked or watching state.
- Shows marked as watching appear on the Schedule page, grouped by their release weekday.

## Development Rules

- Every agent-run development launch or build, including local release-mode verification, must include `--dart-define=TAMASHII_USE_TEST_TORRENT=true`. This forces every download to use the small Big Buck Bunny test torrent instead of API-provided media that can be several GB. This define is not needed for `flutter test`; omit it only for production/distribution builds or when intentionally testing a production magnet.
- Providers should use Riverpod code generation. Prefer `@riverpod` and generated `.g.dart` files over manually declared providers.
- Models should use `@freezed` for data classes instead of handwritten equality, copy, or serialization logic.
- New code must be covered by tests.
- Changed code must be testable. If the current design makes testing difficult, refactor it first so dependencies can be injected and behavior can be exercised by tests.
- When changing behavior, add or update tests in the same change.
- When adding or changing codegen-backed providers or Freezed models, update the generated files as part of the change.
- Always run a full test suite before finishing a task to ensure there are no regressions.
