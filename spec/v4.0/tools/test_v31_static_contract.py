#!/usr/bin/env python3
from pathlib import Path
import json,sqlite3,re,yaml
from jsonschema import Draft202012Validator
root=Path(__file__).resolve().parents[1]
for document in (root/'docs').glob('*.md'):
 assert not re.search(r'\bR2\b',document.read_text(),re.I),document
required=['EU_PRIVACY_COOKIES.md','WCAG_ACCESSIBILITY.md','EU_MARKETPLACE_COMPLIANCE.md','README_COURSE_DESCRIPTION.md','ERROR_FAILURE_SEMANTICS.md','INSTRUCTOR_LFS_GUIDE.md']
assert all((root/'docs'/f).is_file() for f in required)
assert 'README.md' in (root/'docs/README_COURSE_DESCRIPTION.md').read_text()
sub=json.loads((root/'schemas/submission-v3.schema.json').read_text()); Draft202012Validator.check_schema(sub)
file=sub['properties']['files']['items']
assert file['properties']['storage']['const']=='github-lfs'
assert 'pointerPath' in file['required']
assert 'objectKey' not in file['properties']
conn=sqlite3.connect(':memory:')
for f in sorted((root/'db').glob('*.sql')):conn.executescript(f.read_text())
names={x[0] for x in conn.execute("SELECT name FROM sqlite_master WHERE type='table'").fetchall()}
for name in ('consent_events','legal_acceptances','privacy_requests','content_notices','accessibility_issues'):
 assert name in names,name
api=yaml.safe_load((root/'api/openapi.yaml').read_text());paths=api['paths']
for path in ('/legal/{documentType}','/legal/cookie-settings','/privacy/requests','/notices','/courses/{courseId}/description'):
 assert path in paths,path
assert 'strictly necessary' in (root/'docs/EU_PRIVACY_COOKIES.md').read_text().lower()
assert 'WCAG 2.2' in (root/'docs/WCAG_ACCESSIBILITY.md').read_text()
assert '5%' in (root/'docs/EU_MARKETPLACE_COMPLIANCE.md').read_text()
print('V3.1 static contract, privacy, accessibility, SQL, API, storage and policy checks PASS')
