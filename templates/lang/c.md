### C
- C11 unless the project says otherwise; `-Wall -Wextra -Werror`, zero warnings.
- Check every return value. One owner per allocation, freed on every path.
- `<stdint.h>` fixed-width ints, `size_t` for sizes, `const` and `static` by default.
- Bounded string functions only (`snprintf`, `strnlen`); never `gets`, `strcpy`, `sprintf`.
- Headers declare, sources define; `#pragma once`. Tests run under `-fsanitize=address,undefined`.
