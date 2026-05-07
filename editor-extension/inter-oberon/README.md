# InterOberon syntax highlighting

Syntax highlighting for InterOberon source files (`.Mod`) in Cursor / VSCode.

Keywords and built-in names are supported in all three languages that InterOberon understands:

- English (MODULE, BEGIN, END, IF, THEN, …)
- Русский (МОДУЛЬ, НАЧАЛО, КОНЕЦ, ЕСЛИ, ТОГДА, …)
- Latviešu (MODULIS, SĀKUMS, BEIGAS, JA, TAD, …)

The following are also handled correctly:

- nested comments `(* ... (* ... *) ... *)`;
- translation comments `(* **%xx:name* *)` (highlighted in a distinct color);
- strings in double and single quotes;
- numeric literals: integer, `…H` (hex), `…X` (char), `…·…` (real);
- the export marker `*` and read-only marker `-` after a name;
- procedure calls (`name(`) and `MODULE`/`PROCEDURE` headers.

## Local installation

Copy the folder into the Cursor extensions directory and restart the editor:

```bash
cp -r editor-extension/inter-oberon ~/.cursor/extensions/inter-oberon-0.1.0
```

After restarting Cursor, any `.Mod` file will open with syntax highlighting.

## Building .vsix (optional)

```bash
npm install -g @vscode/vsce
cd editor-extension/inter-oberon
vsce package
```

Install it via `Cmd+Shift+P → Extensions: Install from VSIX…`.

## File associations

The extension already registers `.Mod`, `.mod`, `.ob`, `.ob07` with the `oberon` language.
To override this globally, add the following to `settings.json`:

```json
"files.associations": {
  "*.Mod": "oberon"
}
```
