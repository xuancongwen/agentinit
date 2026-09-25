### C
- Use the project's standard (C11 default). Build with `-Wall -Wextra -Werror`; zero warnings.
- Check every return value. Every allocation has exactly one owner and a matching free on all paths.
- Fixed-width ints from `<stdint.h>`, `const` and `static` by default, `size_t` for sizes.
- Bounded string functions only (`snprintf`, `strnlen`); never `gets`, `strcpy`, `sprintf`.
- Headers declare, sources define; include guards or `#pragma once`.
- Run under `-fsanitize=address,undefined` in tests. Frameworks: Unity, cmocka, or Check.
