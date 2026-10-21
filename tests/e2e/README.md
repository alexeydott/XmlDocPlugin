# IDE end-to-end checks

Run controlled-transport AI and editor checks against the installed packages:

```powershell
tests/e2e/Test-E2E.ps1 -Installed -AIOnly
```

This mode exercises reviewed OTA writes, Undo/Redo, independent section choices,
method navigation, numeric and string overload resolution, lexical shadowing,
waiting for a delayed native acknowledgement, source-conflict rejection and IDE
shutdown. It uses copied projects and isolated IDE settings.

For real requests with an existing connection profile and **no application of
proposals**, use the separate review-only mode:

```powershell
tests/e2e/Test-E2E.ps1 -Installed -LiveAIReview -LiveAIProfile 'Your profile'
```

This sends Describe and Review requests for the sample function, then reviews two
methods through the queue. It records the offered parameters, Returns, Remarks
and correction explanations. Optional sections are recorded as absent when the
provider omits them. It never clicks Apply and verifies that both source buffers
and files remain unchanged before closing each IDE. These requests consume the
configured provider's quota. Response and request evidence stays outside Git;
Authorization headers and stored credentials are not captured.

The PasDoc installed-package scenario uses the bundled synthetic Pascal unit and its
same-name text sidecar. Pass `-Installed -PasDocSourceDirectory 'tests/e2e/DocumentationWorkbench/Units'
-LargeProject 'tests/e2e/DocumentationWorkbench/XmlDocE2E.dproj'`. It checks
TPasDocSample and ConvertValue descriptions, sidecar parameter mapping, relative
`@include`/`@includeCode`, acknowledged OTA application and exact Undo before
closing each IDE. Original Pascal and text files are never written.

The older `-RealAI` mode has a different purpose: it tests reviewed application
and Undo on a large source method. Do not use that mode for review-only checks.
