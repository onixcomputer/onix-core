## ADDED Requirements

### Requirement: HexColor contract validates format
The NCL `HexColor` contract SHALL accept only strings matching `^#[0-9a-fA-F]{6}$` and reject all other values with a descriptive error message.

#### Scenario: Valid hex color passes
- **WHEN** a value `"#ff6600"` is applied against the `HexColor` contract
- **THEN** validation succeeds

#### Scenario: Missing hash prefix rejected
- **WHEN** a value `"ff6600"` is applied against the `HexColor` contract
- **THEN** validation fails with a message indicating the expected `#rrggbb` format

#### Scenario: Wrong length rejected
- **WHEN** a value `"#ff660"` is applied against the `HexColor` contract
- **THEN** validation fails with a message indicating the expected `#rrggbb` format

#### Scenario: Non-hex characters rejected
- **WHEN** a value `"#gghhii"` is applied against the `HexColor` contract
- **THEN** validation fails with a message indicating the expected `#rrggbb` format

### Requirement: Color record pre-computes derived forms
The NCL `mk_color` function SHALL take a hex string and return a record containing `hex`, `no_hash`, `rgb`, and `ansi` fields with correctly computed values.

#### Scenario: Derived forms for orange
- **WHEN** `mk_color "#ff6600"` is evaluated
- **THEN** the result is `{ hex = "#ff6600", no_hash = "ff6600", rgb = "255, 102, 0", ansi = "38;2;255;102;0" }`

#### Scenario: Derived forms for black
- **WHEN** `mk_color "#000000"` is evaluated
- **THEN** the result is `{ hex = "#000000", no_hash = "000000", rgb = "0, 0, 0", ansi = "38;2;0;0;0" }`

#### Scenario: Uppercase hex normalized
- **WHEN** `mk_color "#FF6600"` is evaluated
- **THEN** `no_hash` is `"ff6600"` (lowercase)

### Requirement: ThemeSchema contract enforces required fields
The NCL `ThemeSchema` contract SHALL require all base surface colors (base00-base07), all semantic colors (red, orange, yellow, green, cyan, blue, purple, magenta), and all 16 terminal colors. Missing required fields SHALL produce a contract error at `ncl export` time.

#### Scenario: Complete theme passes validation
- **WHEN** a theme record includes all required surface, semantic, and terminal color fields
- **THEN** validation succeeds and `ncl export` produces JSON output

#### Scenario: Missing semantic color rejected
- **WHEN** a theme record omits the `green` semantic color
- **THEN** `ncl export` fails with an error identifying the missing field

### Requirement: ThemeSchema allows optional extension blocks
The NCL `ThemeSchema` contract SHALL accept optional blocks `editor`, `zen`, `rainbow`, `btop`, `waybar`, and `misc`. When omitted, the `mk_theme` builder SHALL provide default values. When present, all fields within the block SHALL be validated as `HexColor`.

#### Scenario: Theme without editor block uses defaults
- **WHEN** a theme omits the `editor` extension block
- **THEN** `mk_theme` produces a complete theme with default editor colors

#### Scenario: Theme with partial editor block rejected
- **WHEN** a theme provides an `editor` block missing required sub-fields
- **THEN** validation fails identifying the missing editor fields

### Requirement: mk_theme builder provides defaults and merges
The NCL `mk_theme` function SHALL accept a theme spec with required fields and optional overrides, merge with defaults for terminal colors (fallback to semantic colors), optional extensions, opacity, and waybar styling, then return a fully expanded theme record with all derived color forms pre-computed.

#### Scenario: Terminal colors default to semantic colors
- **WHEN** a theme spec omits `term_red`
- **THEN** `mk_theme` sets `term_red` to the value of `red`

#### Scenario: Explicit terminal color overrides default
- **WHEN** a theme spec sets `term_red = "#ff7a93"`
- **THEN** `mk_theme` uses `"#ff7a93"` for `term_red`, not the `red` semantic color

#### Scenario: All output colors have derived forms
- **WHEN** `mk_theme` produces a theme
- **THEN** every color field in the output is a record with `hex`, `no_hash`, `rgb`, and `ansi` keys
