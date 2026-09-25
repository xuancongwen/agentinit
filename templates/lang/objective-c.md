### Objective-C
- ARC only. Properties `nonatomic`; `copy` for `NSString` and blocks; `weak` for delegates and to break cycles.
- Wrap headers in `NS_ASSUME_NONNULL_BEGIN`/`END`; use lightweight generics and `instancetype`.
- Literals (`@[]`, `@{}`, `@()`), dot syntax for properties, `NSError **` for failures; no exceptions for control flow.
- Capture `weakSelf` in escaping blocks; no `+load` side effects.
- clang-format clean; tests in XCTest.
