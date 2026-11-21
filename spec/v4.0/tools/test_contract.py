from pathlib import Path
import json, yaml, subprocess,sys,tempfile
from jsonschema import Draft202012Validator,FormatChecker
r=Path(__file__).resolve().parents[1]
for name in ('course','submission','grade'):
 schema=json.loads((r/'schemas'/f'{name}-v3.schema.json').read_text())
 Draft202012Validator.check_schema(schema)
 p=r/'templates'/f'{name}.yaml'; x=yaml.safe_load(p.read_text())
 Draft202012Validator(schema,format_checker=FormatChecker()).validate(x)
 print('Schema + minimal template valid:',name)
example=r/'examples/complete.course.yaml'
p=subprocess.run([sys.executable,str(r/'tools/validate_course.py'),str(example)],capture_output=True,text=True)
if p.returncode:raise RuntimeError(p.stderr)
print('Semantic example valid:',example)
with tempfile.TemporaryDirectory() as tmp:
 q=Path(tmp)/'course.yaml';q.write_text('schemaVersion: 3\nschemaVersion: 3\ncourse: {}\noutline: []\nassignments: []\n')
 p=subprocess.run([sys.executable,str(r/'tools/validate_course.py'),str(q)],capture_output=True,text=True)
 assert p.returncode,'Duplicate key must be rejected'
print('Negative duplicate YAML key case rejected')

# v3 extension results and automatic-grading fixture
auto=yaml.safe_load((r/'examples/auto-grading.course.yaml').read_text())
s=json.loads((r/'schemas/course-v3.schema.json').read_text())
Draft202012Validator(s,format_checker=FormatChecker()).validate(auto)
result=json.loads((r/'examples/grading-result.json').read_text())
result_schema=json.loads((r/'schemas/grading-result-v1.schema.json').read_text())
Draft202012Validator(result_schema).validate(result)
print('V3 automatic grading and output contracts valid')
