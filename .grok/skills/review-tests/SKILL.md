---
name: review-tests
description: >
  Judge tests against the behavior they claim to protect. Delete a test
  that would still pass if the behavior were wrong, or rewrite it to a
  literal observable outcome. Use after writing or changing tests, before
  claiming a phase done, and when the user runs /review-tests.
---

# Review tests

Review every test added or changed in the current work before it is committed. Mechanical bans live in `tool/deslop.dart`. Run that lint. Do the judgment here.

For each test:

1. Read the test, the production code it exercises, and the behavior the test name claims.
2. Ask: if this behavior were wrong, would this test fail?
3. Classify what you find:
   - Tautology or mirrored oracle: the expected value is computed by the same logic, or the assert restates the implementation.
   - Weak assertion: the matcher would accept many wrong results.
   - Over-mock: the logic under test is mocked. A second `CloudStore`, including `FakeCloudStore`, is allowed.
   - Conditional pass: a branch, skip, or catch lets the test pass either way.
   - Happy-path-only, where an edge is the actual risk.
   - Duplicate of an existing test.
   - A private method or widget type with no user-visible outcome.
4. If the test protects no behavior, delete it. If the behavior is worth protecting, rewrite the test so the expected value is a literal a person can observe: text, checked state, aisle name, file body, or a conflict.
5. Do not weaken, skip, or delete a test to make a run green. Do not add a test whose only purpose is to satisfy the linter.
6. A floor of 400 dictionary phrases, asserted with `greaterThanOrEqualTo(400)`, stays a floor.

Then run `dart run tool/deslop.dart` again.

Report what you deleted, what you rewrote, and, for each surviving test, the wrong outcome that would fail it.
