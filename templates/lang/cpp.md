### C++
- C++17 or later per project. RAII everywhere; `std::unique_ptr` by default, `shared_ptr` only for real shared ownership, no raw `new`/`delete`.
- Follow the C++ Core Guidelines: `const`/`constexpr` by default, `explicit` single-arg constructors, `override`/`final`, rule of zero.
- Prefer `std::` algorithms, `string_view`, `span`, `optional`, and `variant` over raw pointers and sentinels.
- clang-format and clang-tidy clean; sanitizers in CI; no `using namespace` in headers.
- Tests: GoogleTest or Catch2. Build: CMake with presets.
