# AGENTS.md

## Development Rules

- Providers should use Riverpod code generation. Prefer `@riverpod` and generated `.g.dart` files over manually declared providers.
- Models should use `@freezed` for data classes instead of handwritten equality, copy, or serialization logic.
- New code must be covered by tests.
- Changed code must be testable. If the current design makes testing difficult, refactor it first so dependencies can be injected and behavior can be exercised by tests.
- When changing behavior, add or update tests in the same change.
- When adding or changing codegen-backed providers or Freezed models, update the generated files as part of the change.
