### C++
- C++17+; RAII everywhere. `unique_ptr` by default, `shared_ptr` only for true shared ownership, no raw `new`/`delete`.
- Core Guidelines: `const`/`constexpr` by default, `explicit` constructors, `override`, rule of zero.
- `std::` algorithms, `string_view`, `span`, `optional`, `variant` over raw pointers and sentinels.
- clang-format and clang-tidy clean; no `using namespace` in headers; sanitizers in CI.
- Tests: GoogleTest or Catch2. Build: CMake presets.
