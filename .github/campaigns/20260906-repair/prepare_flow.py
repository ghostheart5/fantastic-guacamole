"""One observed-anchor swipe in an isolated execution copy; app checkout stays unchanged."""
import hashlib
import json
from pathlib import Path
import shutil
import sys

SOURCE_FLOW_SHA256 = 'b3450da2ccf3bcc9106d9801d777ea8634799a861d19d05e850ca5170d6d896b'
SWIPE = '- swipe:\n    from:\n      text: "SCHEDULE"\n    direction: UP\n    duration: 600\n'

def digest(text):
    return hashlib.sha256(text.encode('utf-8')).hexdigest()

def adjusted(original):
    if digest(original) != SOURCE_FLOW_SHA256:
        raise ValueError('Original lifecycle flow changed')
    marker = '# The Planner draft is still read-only until Creator review and confirmation.'
    before, after = original.split(marker)
    target = '- scrollUntilVisible:\n    element:\n      text: "REVIEW CHANGES"\n    direction: DOWN\n    timeout: 10000\n'
    if after.count(target) != 1:
        raise ValueError('Expected exactly one Planner-draft review scroll')
    changed = before + marker + after.replace(target, SWIPE + target)
    if changed.replace(SWIPE,'',1) != original:
        raise ValueError('Unexpected change outside one added swipe')
    return changed

def prepare(source):
    origin = source / '.maestro/flows/priority8-learned-lifecycle.yaml'
    original = origin.read_text(encoding='utf-8')
    changed = adjusted(original)
    output = source / 'test-results/hosted-overrides'
    output.mkdir(exist_ok=False)
    (output / 'flows').mkdir()
    shutil.copytree(source / '.maestro/subflows',output / 'subflows')
    execution = output / 'flows/priority8-learned-lifecycle.yaml'
    execution.write_text(changed,encoding='utf-8')
    campaign = source / 'test-results/hosted-campaign'
    (campaign / 'controls/executed-priority8-learned-lifecycle.yaml').write_text(changed,encoding='utf-8')
    (campaign / 'controls/original-priority8-learned-lifecycle.yaml').write_text(original,encoding='utf-8')
    receipt = {'originalCanonicalSha256':digest(original),'executionCanonicalSha256':digest(changed),
               'originalAssertionsAndTimeoutsPreserved':True,'onlyAddedCommand':'swipe UP from observed SCHEDULE label, 600ms',
               'applicationSourceChanged':False,'appliesToRebuiltRepairApk':True}
    (campaign / 'flow-override.json').write_text(json.dumps(receipt,indent=2)+'\n',encoding='utf-8')
    print(json.dumps(receipt))

if __name__ == '__main__':
    prepare(Path(sys.argv[1]))
