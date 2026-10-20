# XmlDoc.AI.ProfileStore

Reads AI profiles and scoped credentials without IDE or form dependencies.

## Functions & Procedures

### AIConfigurationPath

Returns the per-user profile file, or the explicitly overridden configuration path.

### AICredentialTarget

Scopes a credential identity to the profile and the exact request destination.

### AIProfileFromJson

Loads connection options and limits while retaining defaults for absent optional fields.

### LoadAIConfiguration

Reads a supported profile document without changing it or loading IDE services.

### ReadAIKey

Reads the scoped Windows credential without exposing it in profile JSON.
