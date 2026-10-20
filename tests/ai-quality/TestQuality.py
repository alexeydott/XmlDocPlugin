import importlib.util,pathlib,unittest,json
path=pathlib.Path(__file__).parent;spec=importlib.util.spec_from_file_location('evaluate',path/'Evaluate.py');module=importlib.util.module_from_spec(spec);spec.loader.exec_module(module)
class QualityTests(unittest.TestCase):
 def test_missing_and_duplicate_cases_fail(self):
  corpus=json.loads((path/'corpus.json').read_text('utf-8-sig'))
  with self.assertRaises(ValueError):module.evaluate_all(corpus,[])
  with self.assertRaises(ValueError):module.evaluate_all(corpus,[{'id':corpus['cases'][0]['id'],'summary':'x'}]*2)
 def test_supported_paraphrases_and_invented_claims(self):
  cases=json.loads((path/'corpus.json').read_text('utf-8-sig'))['cases']
  summaries=['Uses a hash for an overload; otherwise returns the original name.','Resolves a relative resource to an absolute full path and rejects parent traversal.','Uses a byte-order BOM to detect UTF-8 and other marked encodings, with a default code-page fallback.']
  for case,text in zip(cases,summaries):
   result=module.evaluate(case,{'summary':text,'uncertainties':case['uncertainties']});self.assertFalse(result['missingFacts']);self.assertFalse(result['inventedClaims']);self.assertTrue(result['retainedFacts']);self.assertTrue(result['addedSupportedFacts'])
  self.assertIn('collision-free',module.evaluate(cases[0],{'summary':summaries[0]+' It guarantees a unique identifier.'})['inventedClaims'])
  self.assertIn('existence',module.evaluate(cases[1],{'summary':summaries[1]+' It verifies that the file exists.'})['inventedClaims'])
  self.assertIn('all-encodings',module.evaluate(cases[2],{'summary':summaries[2]+' It always succeeds for all encodings.'})['inventedClaims'])
 def test_facts_can_be_in_independently_reviewed_sections(self):
  case=json.loads((path/'corpus.json').read_text('utf-8-sig'))['cases'][0]
  result=module.evaluate(case,{'summary':'Uses a hash for overloads.','returns':'Otherwise the original name.','remarks':'No extra guarantees.'})
  self.assertFalse(result['missingFacts'])
 def test_expanded_corpus_is_distinct_and_contains_required_scenarios(self):
  corpus=json.loads((path/'corpus.json').read_text('utf-8-sig'));ids=[c['id'] for c in corpus['cases']]
  self.assertEqual(len(ids),len(set(ids)))
  self.assertTrue({'consume','positive','normalize-integer','normalize-string','conditional-scale','generic-pick'}.issubset(ids))
 def test_malformed_parameter_response_is_rejected(self):
  corpus=json.loads((path/'corpus.json').read_text('utf-8-sig'))
  with self.assertRaises(ValueError):module.evaluate_all(corpus,[{'id':corpus['cases'][0]['id'],'summary':'x','parameters':[{'name':'Value','description':None}]}])
 def test_comparison_separates_protocol_failures_and_checks_source_fingerprints(self):
  import Compare
  case={'id':'one','facts':[{'id':'fact','pattern':'supported'}],'existingFacts':['fact'],'unsupported':[],'uncertainties':[]}
  good={'id':'one','summary':'supported','model':'m','promptId':'a','contextFingerprint':'same'}
  bad={'id':'one','summary':'','error':'missing field','model':'m','promptId':'b','contextFingerprint':'same'}
  result=Compare.compare({'cases':[case]},[('first',[good]),('second',[bad])])
  self.assertEqual([],result['commonSuccessfulCases']);self.assertEqual(1,result['runs'][1]['failedRequests']);self.assertEqual(0,result['runs'][1]['missingFacts']);self.assertTrue(result['sourceContextsVerified'])
  with self.assertRaises(ValueError):Compare.compare({'cases':[case]},[('a',[good]),('b',[dict(good,contextFingerprint='changed')])])
 def test_russian_unsupported_claims_distinguish_explicit_negation(self):
  case=json.loads((path/'corpus.json').read_text('utf-8-sig'))['cases'][0]
  self.assertIn('collision-free',module.evaluate(case,{'summary':'Гарантирует уникальность идентификатора.'})['inventedClaims'])
  self.assertNotIn('collision-free',module.evaluate(case,{'summary':'Не гарантирует уникальность идентификатора.'})['inventedClaims'])
if __name__=='__main__':unittest.main()
