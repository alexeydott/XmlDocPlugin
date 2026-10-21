# XmlDoc.PasDoc

Imports PasDoc descriptions, sidecars, includes and structured tags into XML.

## Functions & Procedures

### ImportLegacyComment

Converts a declaration comment and matching sidecar section to XML without writing source files.

**Parameters:**

- **Text** — Comment text without Pascal delimiters.
- **Element** — Declaration identity and signature.
- **ExternalText** — Already loaded same-name text file.
- **ExternalLoaded** — Avoids reading the sidecar again.
- **ReadFile** — Optional snapshot reader which records include dependencies.

**Returns:** XML documentation including expanded file content.

### PasDocMember

Finds a named member/value description inside its owner's PasDoc comment.
