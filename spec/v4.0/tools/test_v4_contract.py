from pathlib import Path
import sqlite3, yaml, re, json
p=Path(__file__).resolve().parents[1]
api=yaml.safe_load((p/'api/openapi.yaml').read_text())
assert api['info']['version']=='4.0.0'
assert '/courses/import' in api['paths'] and '/courses/{courseId}/catalog' in api['paths']
assert api['paths']['/courses']['get']['security']==[]
assert api['paths']['/courses/{courseId}/catalog']['put']['requestBody']['content']['application/json']['schema']['properties']['listing']['enum']==['listed','unlisted']
c=sqlite3.connect(':memory:')
for src in sorted((p/'db').glob('*.sql')): c.executescript(src.read_text())
names={r[1] for r in c.execute('pragma table_info(courses)')}
for k in ['catalog_listing','catalog_title','catalog_summary','catalog_revision','catalog_sort_at','commerce_mode','manifest_version']:
 assert k in names,k
assert 'catalog_search_terms' in {r[0] for r in c.execute("select name from sqlite_master where type='table'")}
idx={r[1] for r in c.execute('pragma index_list(courses)')}
assert 'idx_catalog_listing_recent' in idx
# required default: new courses must not be listed automatically
c.execute("insert into users(uid,first_name,last_name,certificate_name,created_at,updated_at) values('u','Al','Smith','Al Smith','2026','2026')")
c.execute("insert into courses(id,manifest_slug,owner_uid,content_repo_id,content_repo_url,default_branch,visibility,enrollment_policy,status,storage_backend,created_at,updated_at) values('c','intro','u','42','https://github.com/u/c','main','public','open','published','github-lfs','2026','2026')")
assert c.execute("select catalog_listing,manifest_version from courses where id='c'").fetchone()==('unlisted',3)
c.execute("update courses set catalog_listing='listed',catalog_title='Introduction',catalog_sort_at='2026-11-21' where id='c'")
c.execute("insert into catalog_search_terms(course_id,term) values('c','intro')")
assert c.execute("select courses.id from courses join catalog_search_terms x on x.course_id=courses.id where x.term='intro' and catalog_listing='listed'").fetchone()==('c',)
spec=(p/'FULL_SPECIFICATION.md').read_text()
for x in ['Open a course from GitHub','WCAG 2.2','Git LFS','5%','Cache API','catalog_listing','__Host-','README.md','course-v3.schema.json']:
 assert x in spec or x in (p/'docs/CORE_EXPERIENCE_AND_CATALOG.md').read_text(),x
for f in ('IMPLEMENTATION_DECISIONS.md','CORE_EXPERIENCE_AND_CATALOG.md','CACHING_PERFORMANCE_COST.md','COST_MODEL_FINAL.md','RELEASE_TESTS_V4.md'):
 assert (p/'docs'/f).is_file(),f
for f in p.rglob('*'):
 if f.suffix.lower() in ('.md','.yaml','.json','.sql','.dot'):
  assert not re.search(r'\bR2\b',f.read_text(),re.I),str(f)
# Pricing calculations from stated model; 100k and 1M
for n,low,high in ((100_000,5,5.40),(1_000_000,18.40,26.40)):
 count=n*50
 for ms,expect in [(2,low),(10,high)]:
  result=5+.3*max(0,count-10_000_000)/1e6 +.02*max(0,count*ms-30_000_000)/1e6
  assert abs(result-expect)<1e-6,(n,ms,result,expect)
print('V4 SQL, catalog, OpenAPI, pricing, privacy, and documentation checks PASS')
