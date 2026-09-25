### PHP
- PHP 8.2+, `declare(strict_types=1)`; PSR-12 via PHP-CS-Fixer; PHPStan or Psalm passes.
- Type every parameter, return, and property; readonly properties and enums over constants.
- PSR-4 autoloading; never `@`, `extract()`, or `eval()`.
- Prepared statements only; escape all output. Tests: PHPUnit or Pest.
