"""Compare complete model/prompt runs using facts rather than exact prose.

These are review signals, not proof of correctness: inspect missing facts and
suspected unsupported claims against the implementation and retained responses.
"""
import argparse, hashlib, json, pathlib
from Evaluate import evaluate_all

def compare(corpus,runs):
 result=[];fingerprints=None;verified=True;common=None
 for name,responses in runs:
  evaluation=evaluate_all(corpus,responses)
  identities={(r.get('model','unspecified'),r.get('promptId','unspecified')) for r in responses}
  if len(identities)!=1:raise ValueError('A run must use one model/prompt identity')
  model,prompt=next(iter(identities))
  current={r['id']:r.get('contextFingerprint') for r in responses}
  if not all(current.values()):verified=False
  elif fingerprints is not None and current!=fingerprints:raise ValueError('Source context changed between runs')
  else:fingerprints=current
  valid=[c for c in evaluation if not c['error']]
  successful={c['id'] for c in valid};common=successful if common is None else common&successful
  result.append({'run':name,'model':model,'promptId':prompt,'evaluatedCases':len(valid),'retainedFacts':sum(len(c['retainedFacts']) for c in valid),'missingFacts':sum(len(c['missingFacts']) for c in valid),'suspectedUnsupportedClaims':sum(len(c['inventedClaims']) for c in valid),'failedRequests':sum(bool(c['error']) for c in evaluation),'cases':evaluation})
 return {'corpusSHA256':hashlib.sha256(json.dumps(corpus,ensure_ascii=False,sort_keys=True).encode()).hexdigest(),'sourceContextsVerified':verified,'commonSuccessfulCases':sorted(common or []),'reviewRequired':True,'runs':result}

if __name__=='__main__':
 parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('responses',nargs='+',type=pathlib.Path);parser.add_argument('--out',required=True,type=pathlib.Path);args=parser.parse_args()
 corpus=json.loads(pathlib.Path(__file__).with_name('corpus.json').read_text('utf-8-sig'))
 report=compare(corpus,[(p.parent.name,json.loads(p.read_text('utf-8-sig'))) for p in args.responses]);args.out.write_text(json.dumps(report,ensure_ascii=False,indent=2),encoding='utf-8')
