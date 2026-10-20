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
if __name__=='__main__':unittest.main()
