"""Fact-oriented review of AI outputs; accepts paraphrases, reports unsupported claims.
Usage: python Evaluate.py responses.json --out evaluation.json
responses.json: [{"id":"anchor", "summary":"...", "uncertainties":["..."]}, ...]
This scorer does not claim to prove arbitrary prose correct; retain human review.
"""
import argparse,json,pathlib,re

def evaluate(case,response):
 text='\n'.join([response['summary'],response.get('returns',''),response.get('remarks','')]+[p['description'] for p in response.get('parameters',[])])
 present=[fact['id'] for fact in case['facts'] if re.search(fact['pattern'],text,re.I)]
 return {'id':case['id'],'retainedFacts':[f for f in present if f in case['existingFacts']], 'addedSupportedFacts':[f for f in present if f not in case['existingFacts']], 'missingFacts':[f['id'] for f in case['facts'] if f['id'] not in present], 'inventedClaims':[f['id'] for f in case['unsupported'] if re.search(f['pattern'],text,re.I)], 'reportedUncertainties':response.get('uncertainties',[]),'knownUncertainties':case['uncertainties'],'error':response.get('error')}

def evaluate_all(corpus,responses):
 indexed={}
 expected={case['id'] for case in corpus['cases']}
 for response in responses:
  identifier=response['id']
  if identifier not in expected or identifier in indexed:
   raise ValueError('Unknown or duplicate case: '+identifier)
  if not isinstance(response.get('summary'),str):
   raise ValueError('Summary must be text: '+identifier)
  for name in ('returns','remarks'):
   if not isinstance(response.get(name,''),str):raise ValueError('Section must be text: '+identifier)
  if not isinstance(response.get('parameters',[]),list) or any(not isinstance(p,dict) or not isinstance(p.get('name'),str) or not isinstance(p.get('description'),str) for p in response.get('parameters',[])):
   raise ValueError('Parameters must contain named text descriptions: '+identifier)
  indexed[identifier]=response
 missing=expected-indexed.keys()
 if missing:raise ValueError('Missing cases: '+', '.join(sorted(missing)))
 return [evaluate(case,indexed[case['id']]) for case in corpus['cases']]

def main():
 parser=argparse.ArgumentParser();parser.add_argument('responses',type=pathlib.Path);parser.add_argument('--out',type=pathlib.Path);args=parser.parse_args()
 corpus=json.loads(pathlib.Path(__file__).with_name('corpus.json').read_text('utf-8-sig'));responses=json.loads(args.responses.read_text('utf-8-sig'))
 result=evaluate_all(corpus,responses)
 payload=json.dumps(result,ensure_ascii=False,indent=2);print(payload)
 if args.out:args.out.write_text(payload,encoding='utf-8')
 return int(any(item['inventedClaims'] or item['missingFacts'] for item in result))
if __name__=='__main__':raise SystemExit(main())
