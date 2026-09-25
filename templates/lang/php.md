### PHP
- PHP 8.2+ with `declare(strict_types=1)`; PSR-12 via PHP-CS-Fixer; PHPStan or Psalm at the project's level.
- Type every parameter, return, and property; readonly properties and enums over constants.
- Composer PSR-4 autoloading; never `@` suppression, `extract()`, or `eval()`.
- Prepared statements only; escape all output.
- Tests: PHPUnit or Pest.
