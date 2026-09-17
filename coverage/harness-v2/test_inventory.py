"""Run with the same pinned dependencies as inventory.py (see README)."""
import json
from pathlib import Path
import unittest

import inventory as inv


class InventoryTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.root = Path(__file__).resolve().parent

    def rows(self, name):
        return [json.loads(line) for line in (self.root / name).read_text().splitlines()]

    def test_pin_counts_and_every_outline_example(self):
        declarations = self.rows('gherkin-declarations.jsonl')
        cases = self.rows('shared-cases.jsonl')
        self.assertEqual(len(declarations), 395)
        self.assertEqual(len(cases), 728)
        expected = set()
        for declaration in declarations:
            examples = declaration['declaration']['examples']
            if examples:
                for table in examples:
                    for row in table['tableBody']:
                        expected.add(declaration['id'] + f":example-L{row['location']['line']}")
            else:
                expected.add(declaration['id'])
        self.assertEqual(expected, {c['id'] for c in cases})

    def test_all_steps_and_assertions_accounted_for(self):
        cases = self.rows('legacy-cases.jsonl')
        assertions = self.rows('migration-crosswalk.jsonl')
        actions = {a['name']: a for a in self.rows('legacy-actions.jsonl')}
        expected = set()
        for case in cases:
            for step in case['steps']:
                action = actions[step['input']['action']]
                if step['kind'] == 'assertion' or action['assertion_sites']:
                    expected.add(step['id'] + ':assertion')
                self.assertGreater(step['source']['line'], 0)
        self.assertEqual(len(cases), 157)
        self.assertEqual(sum(len(c['steps']) for c in cases), 1066)
        self.assertEqual(expected, {a['id'] for a in assertions})
        self.assertEqual(sum(a['kind'] == 'explicit' for a in assertions), 375)
        self.assertEqual(sum(a['kind'] == 'helper_embedded' for a in assertions), 143)
        local = [c for c in cases if c['suite'] == 'feature_flags_local_evaluation']
        # Preserve individual evaluation vectors and full definition snapshots.
        self.assertEqual(len(local), 4)
        self.assertGreater(sum(len(c['steps']) for c in local), 250)
        self.assertTrue(any(s['input']['action'] == 'configure_local_evaluation_definitions'
                            and s['input']['params']['definitions'] for c in local for s in c['steps']))

    def test_catalog_fields_and_candidates_are_not_coverage(self):
        routes = self.rows('catalog-routes.jsonl')
        configs = self.rows('catalog-config.jsonl')
        self.assertEqual(len({r['route'] for r in routes}), 180)
        self.assertEqual(len({r['path'] for r in configs}), 143)
        paths = {r['path'] for r in configs}
        self.assertIn('config.bootstrap.feature_flag_payloads', paths)
        self.assertIn('config.metrics.network.attributes', paths)
        self.assertIn('config.capture_pageview.capture_hash_changes', paths)
        ids = {c['id'] for c in self.rows('shared-cases.jsonl')}
        for row in routes + configs:
            self.assertEqual(row['covered_case_ids'], [])
            self.assertEqual(row['status'], 'unresolved')
            self.assertTrue(row['blocker'])
            self.assertTrue(row['untested_behavior'])
            self.assertTrue(set(row.get('candidate_case_ids', row.get('text_candidate_case_ids', []))) <= ids)
        with self.assertRaisesRegex(ValueError, 'digest changed'):
            inv.catalog_inventory((self.root / 'inputs/public-rpc-catalog.txt').read_text() + '\n')

    def test_backgrounds_outlines_rules_tags_tables_and_docstrings(self):
        feature = '''@feature
Feature: Example
  Background:
    Given outer setup
  @rule
  Rule: Nested
    Background:
      Given rule setup
    @outline
    Scenario Outline: Values <value>
      When send <value>
        """json
        {"value": <value>}
        """
      Then observe
        | value | omitted |
        | <value> |  |
      @examples
      Examples:
        | value |
        | false |
        | null |
        | 0 |
'''
        def read(which, path):
            return feature if path.endswith('.feature') else '### Requirement: Example\n'
        declarations, cases = inv.gherkin_inventory(['acceptance/public/example.feature'], read, {})
        self.assertEqual(len(declarations), 1)
        self.assertEqual(len(cases), 3)
        self.assertEqual([s['text'] for s in cases[0]['steps'][:2]], ['outer setup', 'rule setup'])
        self.assertEqual(cases[0]['tags'], ['@feature', '@rule', '@outline', '@examples'])
        for case, value in zip(cases, ['false', 'null', '0']):
            self.assertEqual(case['steps'][2]['argument']['docString']['content'], '{"value": ' + value + '}')
            self.assertEqual(case['steps'][3]['argument']['dataTable']['rows'][1]['cells'],
                             [{'value': value}, {'value': ''}])
            self.assertIsNotNone(case['example'])
        # Inserting unrelated whitespace changes discovery locations; the real
        # ledger always reads its immutable Git pin, not a moving worktree file.
        self.assertEqual(len({c['id'] for c in cases}), 3)

    def test_yaml_aliases_types_and_source_locations(self):
        data = inv.yaml.load('base: &base\n  value: false\nstep:\n  <<: *base\n  zero: 0\n  null: null\n  empty: ""\n', Loader=inv.LocatedLoader)
        self.assertIs(data['step']['value'], False)
        self.assertEqual(data['step']['zero'], 0)
        self.assertIsNone(data['step'][None])  # YAML 1.1 source loader semantics.
        self.assertEqual(data['step']['empty'], '')
        self.assertEqual(data['step'].line, 4)
        self.assertNotIn('missing', data['step'])

    def test_helper_assertions_and_compound_calls_are_visible(self):
        actions = {a['name']: a for a in self.rows('legacy-actions.jsonl')}
        self.assertEqual(len(actions['get_feature_flag']['assertion_sites']), 3)
        self.assertEqual(len(actions['reload_feature_flag_definitions']['assertion_sites']), 2)
        self.assertIn('for i in range(count)', actions['capture_multiple']['implementation'])
        self.assertIn('ctx.reset()', actions['reset']['implementation'])
        self.assertEqual(actions['assert_capture_fails']['assertion_sites'], [])
        self.assertIn('pass', actions['assert_capture_fails']['implementation'])

    def test_annotations_cannot_erase_or_invent_identities(self):
        with self.assertRaisesRegex(ValueError, 'Unknown annotation identity'):
            inv.apply_notes([], [], {'shared_cases': {'missing': {}}, 'assertions': {}})
        with self.assertRaisesRegex(ValueError, 'Unsupported annotation fields'):
            inv.apply_notes([{'id': 'a'}], [], {'shared_cases': {'a': {'id': 'b'}}, 'assertions': {}})
        with self.assertRaisesRegex(ValueError, 'Unknown candidate case'):
            inv.apply_notes([], [{'id': 'a'}], {'shared_cases': {}, 'assertions': {'a': {'candidate_case_ids': ['missing']}}})

    def test_artifact_integrity(self):
        manifest = json.loads((self.root / 'manifest.json').read_text())
        self.assertEqual(inv.digest((self.root / 'mapping-notes.json').read_text()), manifest['mapping_notes_sha256'])
        for name, expected in manifest['generated_sha256'].items():
            self.assertEqual(inv.digest((self.root / name).read_text()), expected, name)
        for case in self.rows('shared-cases.jsonl'):
            self.assertEqual(case['binding_status'], 'not_implemented')
            self.assertEqual(case['validation_evidence'], [])
            self.assertTrue(case['fixture_needs']['blocker'])


if __name__ == '__main__':
    unittest.main()
