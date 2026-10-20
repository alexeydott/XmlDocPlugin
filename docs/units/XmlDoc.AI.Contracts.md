# XmlDoc.AI.Contracts

Shared request, context, transport and reviewable proposal contracts for AI documentation.

## Types

| Type | Kind | Description |
|------|------|-------------|
| [`EAIError`](XmlDoc.AI.Contracts.EAIError.md) | class | Reports invalid AI configuration, context, transport or response data without accepting a proposal. |
| [`IAITransport`](XmlDoc.AI.Contracts.IAITransport.md) | interface |  |
| [`TAIContext`](XmlDoc.AI.Contracts.TAIContext.md) | record |  |
| [`TAIHttpRequest`](XmlDoc.AI.Contracts.TAIHttpRequest.md) | record |  |
| [`TAIHttpResponse`](XmlDoc.AI.Contracts.TAIHttpResponse.md) | record |  |
| [`TAIParameter`](XmlDoc.AI.Contracts.TAIParameter.md) | record | Plain parameter prose returned by a provider; the host validates declaration names before applying it. |
| [`TAIProfile`](XmlDoc.AI.Contracts.TAIProfile.md) | record |  |
| [`TAIProposal`](XmlDoc.AI.Contracts.TAIProposal.md) | record | Independently reviewable summary, parameter, return and remark proposals with correction reasons and uncertainties. |
| [`TAIOperation`](XmlDoc.AI.Contracts.TAIOperation.md) | type |  |
