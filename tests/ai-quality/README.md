# AI documentation quality checks

The corpus fixes source methods and implementation facts rather than one preferred
wording. It covers `var`/`out`, early exits, explicit exceptions, overloads,
generics, an include-controlled compilation branch, and existing Russian prose.
The standalone smoke project checks the fixture's runtime behavior in RAD 11/12/13
Win32 and Win64. Native tests also verify exact method-context extraction.

Run the offline checks without contacting a provider:

```powershell
tests/ai-quality/Test-Quality.ps1
```

To compare two prompt variants with an existing connection profile:

```powershell
tests/ai-quality/Test-Quality.ps1 -RunLive -ProfileName 'Your profile'
```

Live requests consume the configured provider's quota. Credentials are read from
Windows Credential Manager and never written to evidence. Profiles are not
modified. Requests, raw responses, errors and comparison reports stay outside the
checkout under the evidence directory. Repeat with another profile to compare
models, then pass complete `responses.json` files to `Compare.py`.

Reports separate protocol/request failures from documentation quality. Among valid
responses they show retained facts, missing conditions and suspected unsupported
claims across summary, parameters, returns and remarks. Compare fact quality only
for `commonSuccessfulCases`; different successful subsets do not establish a
winner. A source-context fingerprint detects changed implementations between
runs. Older results without fingerprints are explicitly marked unverified.

Pattern matches are review signals. Inspect their context, negation, uncertainties
and the implementation before concluding that a factual claim is missing or
invented. No exact prose match is required, and a passing report does not replace
review of a proposal before Apply.
