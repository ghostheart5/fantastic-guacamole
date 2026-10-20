import json
import tempfile
import unittest
from pathlib import Path

from prepare_isolated_maestro_flows import prepare, QA_PACKAGE


class IsolatedFlowTests(unittest.TestCase):
    def test_copies_dependencies_changes_only_package_and_preserves_source(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            source = root / 'repo' / '.maestro'
            (source / 'flows').mkdir(parents=True)
            (source / 'subflows').mkdir()
            flow = source / 'flows' / 'test.yaml'
            raw = b'appId: com.ghostheart5.chronospark\r\ntags:\r\n  - core\r\n---\r\n- runFlow: ../subflows/login.yaml\r\n'
            flow.write_bytes(raw)
            dependency = source / 'subflows' / 'login.yaml'
            dependency.write_text('appId: com.ghostheart5.chronospark\n---\n- tapOn: Create profile\n')
            result = prepare([flow, flow], root / 'output')
            self.assertEqual(result[0], result[1])
            self.assertEqual(flow.read_bytes(), raw)
            self.assertEqual(Path(result[0]).read_bytes(), raw.replace(
                b'appId: com.ghostheart5.chronospark\r', ('appId: ' + QA_PACKAGE).encode()))
            self.assertIn('Create profile', (Path(result[0]).parent.parent / 'subflows/login.yaml').read_text())
            receipt = json.loads((root / 'output/flow-remapping.json').read_text())
            self.assertEqual(len(receipt['files']), 2)
            self.assertNotEqual(receipt['files'][0]['sourceSha256'], receipt['files'][0]['preparedSha256'])

    def test_rejects_non_maestro_flow(self):
        with tempfile.TemporaryDirectory() as directory:
            flow = Path(directory) / 'flow.yaml'
            flow.write_text('appId: com.ghostheart5.chronospark\n')
            with self.assertRaises(ValueError):
                prepare([flow], Path(directory) / 'output')

    def test_rejects_output_inside_source(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory) / '.maestro'
            root.mkdir()
            flow = root / 'flow.yaml'
            flow.write_text('appId: com.ghostheart5.chronospark\n')
            with self.assertRaises(ValueError):
                prepare([flow], root / 'output')

    def test_keeps_distinct_custom_source_trees_separate(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            flows = []
            for name in ('application', 'custom'):
                source = root / name / '.maestro'
                source.mkdir(parents=True)
                flow = source / 'same.yaml'
                flow.write_text('appId: com.ghostheart5.chronospark\n---\n- tapOn: ' + name + '\n')
                flows.append(flow)
            result = prepare(flows, root / 'output')
            self.assertNotEqual(result[0], result[1])
            self.assertIn('application', Path(result[0]).read_text())
            self.assertIn('custom', Path(result[1]).read_text())

    def test_rejects_wrong_or_duplicate_package_headers(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            for index, text in enumerate((
                'appId: another.package\n---\n',
                'appId: com.ghostheart5.chronospark\nappId: com.ghostheart5.chronospark\n---\n',
            )):
                source = root / str(index) / '.maestro'
                source.mkdir(parents=True)
                flow = source / 'flow.yaml'
                flow.write_text(text)
                with self.assertRaises(ValueError):
                    prepare([flow], root / ('output' + str(index)))


if __name__ == '__main__':
    unittest.main()
