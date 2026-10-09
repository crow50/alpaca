"""Reads the output of yaml_fuzz.pl on stdin and reports how many generated playbooks
lose or corrupt the password when parsed by PyYAML (the parser Ansible uses)."""
import collections
import re
import sys

import yaml

text = sys.stdin.read()
chunks = re.findall(r"@@@PW:(.*?)\n(.*?)@@@END", text, re.S)
n = len(chunks)
bad = collections.Counter()
examples = collections.defaultdict(list)

for password, doc in chunks:
    try:
        parsed = yaml.safe_load(doc)
        got = parsed[0]["vars"]["users"]["root"][0]
        if got is None:
            kind = "silently becomes null (password lost)"
        elif not isinstance(got, str):
            kind = "wrong type (" + type(got).__name__ + ")"
        elif got != password:
            kind = "different string"
        else:
            continue
    except yaml.YAMLError:
        kind = "YAML PARSE ERROR (the play cannot load)"
    bad[kind] += 1
    if len(examples[kind]) < 5:
        examples[kind].append(password)

total_bad = sum(bad.values())
print(f"   playbooks generated : {n}")
print(f"   broken or altered   : {total_bad}  ({100 * total_bad / max(n, 1):.1f}%)")
for kind, count in bad.most_common():
    print(f"      {count:5d}  {kind:42s} e.g. {examples[kind]}")
