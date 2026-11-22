"""Check the corrected OpenAPI contract without fetching remote references."""

import re
import unittest
from pathlib import Path
from urllib.parse import unquote, urlsplit

import yaml
from jsonschema import Draft202012Validator


SPEC = Path(__file__).resolve().parents[1] / "spec"
CONTRACT = SPEC / "errata" / "openapi.yaml"
UPSTREAM = SPEC / "v4.0" / "api" / "openapi.yaml"
HTTP_METHODS = {"delete", "get", "head", "options", "patch", "post", "put", "trace"}
PUBLIC = {
    ("get", "/health"),
    ("get", "/courses"),
    ("post", "/courses/import"),
    ("get", "/preview/{repoId}/{sha}"),
    ("get", "/preview/{repoId}/{sha}/readme"),
    ("get", "/preview/{repoId}/{sha}/files/{path}"),
    ("get", "/preview/{repoId}/{sha}/folders/{lessonId}/{resourceId}"),
    ("get", "/preview/{repoId}/{sha}/content/{lessonId}/{resourceId}"),
    ("get", "/legal/{documentType}"),
    ("get", "/certificates/{certificateId}"),
}
PROVIDER_AUTH = {
    ("post", "/github/webhook"): [{"GitHubSignature": []}],
    ("post", "/stripe/webhook"): [{"StripeSignature": []}],
}
API_ERROR = {"$ref": "#/components/schemas/ApiError"}
IDEMPOTENCY_KEY = {"$ref": "#/components/parameters/IdempotencyKey"}


def operations(document):
    return {
        (method, path): operation
        for path, item in document["paths"].items()
        for method, operation in item.items()
        if method in HTTP_METHODS
    }


def references(node):
    if isinstance(node, dict):
        if "$ref" in node:
            yield node["$ref"]
        for value in node.values():
            yield from references(value)
    elif isinstance(node, list):
        for value in node:
            yield from references(value)


# Public reads that also accept a session, so private courses can be served
# to enrolled readers (spec: public course offers and manifests).
OPTIONAL_AUTH = {
    ("get", "/courses/{courseId}/manifest"),
    ("get", "/courses/{courseId}/offers"),
}

class OpenApiContractTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.document = yaml.safe_load(CONTRACT.read_text(encoding="utf-8"))
        cls.documents = {CONTRACT: cls.document}
        cls.operations = operations(cls.document)

    def resolve_reference(self, reference, source=CONTRACT):
        url = urlsplit(reference)
        self.assertFalse(url.scheme or url.netloc or url.query, reference)
        target = (source.parent / unquote(url.path)).resolve() if url.path else source
        self.assertTrue(target.is_relative_to(SPEC), reference)
        if target not in self.documents:
            self.documents[target] = yaml.safe_load(target.read_text(encoding="utf-8"))
        node = self.documents[target]
        pointer = unquote(url.fragment)
        if pointer:
            self.assertTrue(pointer.startswith("/"), reference)
            for part in pointer[1:].split("/"):
                key = part.replace("~1", "/").replace("~0", "~")
                node = node[int(key)] if isinstance(node, list) else node[key]
        self.assertIsNotNone(node, reference)
        return target, node

    def resolve_object(self, node):
        if "$ref" in node:
            _, node = self.resolve_reference(node["$ref"])
        return node

    def test_openapi_version_and_operations(self):
        self.assertRegex(self.document["openapi"], r"^3\.1\.\d+$")
        upstream = yaml.safe_load(UPSTREAM.read_text(encoding="utf-8"))
        expected = set(operations(upstream))
        expected.remove(("get", "/courses/{courseId}/content/{resourceId}"))
        expected.add(("get", "/courses/{courseId}/content/{lessonId}/{resourceId}"))
        self.assertLessEqual(expected | PUBLIC, self.operations.keys())

        operation_ids = set()
        for route, operation in self.operations.items():
            with self.subTest(route=route):
                operation_id = operation.get("operationId")
                self.assertIsInstance(operation_id, str)
                self.assertTrue(operation_id.strip())
                self.assertNotIn(operation_id, operation_ids)
                operation_ids.add(operation_id)

    def test_path_parameters(self):
        for (method, path), operation in self.operations.items():
            with self.subTest(method=method, path=path):
                parameters = {}
                for location in [self.document["paths"][path], operation]:
                    for entry in location.get("parameters", []):
                        parameter = self.resolve_object(entry)
                        if parameter["in"] == "path":
                            parameters[parameter["name"]] = parameter
                self.assertEqual(set(parameters), set(re.findall(r"\{([^}]+)\}", path)))
                for parameter in parameters.values():
                    self.assertIs(parameter["required"], True)
                    schema = self.resolve_object(parameter["schema"])
                    self.assertIn(schema["type"], {"string", "integer"})

    def test_explicit_security(self):
        self.assertNotIn("security", self.document)
        for route, operation in self.operations.items():
            with self.subTest(route=route):
                security = operation["security"]
                if route in PUBLIC:
                    self.assertEqual(security, [])
                elif route in OPTIONAL_AUTH:
                    # Anonymous for public courses, signed in for private ones.
                    self.assertEqual(security, [{}, {"WebSession": []}, {"FirebaseBearer": []}])
                elif route in PROVIDER_AUTH:
                    self.assertEqual(security, PROVIDER_AUTH[route])
                else:
                    self.assertIsInstance(security, list)
                    self.assertTrue(security)
                    for requirement in security:
                        self.assertIn(requirement, [{"WebSession": []}, {"FirebaseBearer": []}])

    def test_error_responses_use_api_error(self):
        for route, operation in self.operations.items():
            for status, entry in operation["responses"].items():
                if str(status).startswith(("4", "5")):
                    with self.subTest(route=route, status=status):
                        response = self.resolve_object(entry)
                        self.assertEqual(set(response["content"]), {"application/json"})
                        self.assertEqual(response["content"]["application/json"]["schema"], API_ERROR)

        schema = self.document["components"]["schemas"]["ApiError"]
        validator = Draft202012Validator(schema)
        error = {"code": "not_found", "message": "Not found", "requestId": "42", "retryable": False}
        validator.validate(error)
        validator.validate(dict(error, retryAfterSeconds=30, details={"field": "url"}))
        for field in error:
            with self.subTest(required=field):
                self.assertFalse(validator.is_valid({k: v for k, v in error.items() if k != field}))

    def test_mutations_use_the_uuid_header(self):
        header = self.resolve_object(IDEMPOTENCY_KEY)
        self.assertEqual((header["name"], header["in"], header["required"]),
                         ("Idempotency-Key", "header", True))
        self.assertEqual(header["schema"], {"type": "string", "format": "uuid"})
        for (method, path), operation in self.operations.items():
            if method not in {"post", "put", "patch", "delete"}:
                continue
            with self.subTest(method=method, path=path):
                uses_header = IDEMPOTENCY_KEY in operation.get("parameters", [])
                self.assertEqual(uses_header, path != "/courses/import" and
                                 (method, path) not in PROVIDER_AUTH)

    def test_references_resolve(self):
        pending = {CONTRACT}
        checked = set()
        while pending:
            source = pending.pop()
            checked.add(source)
            document = self.documents[source]
            for reference in set(references(document)):
                with self.subTest(source=source.relative_to(SPEC), reference=reference):
                    target, _ = self.resolve_reference(reference, source)
                    if target not in checked:
                        pending.add(target)

    def test_json_schemas_parse(self):
        for name, schema in self.document["components"]["schemas"].items():
            with self.subTest(schema=name):
                Draft202012Validator.check_schema(schema)

    def test_outline_is_the_reader_contract(self):
        def response_schema(method, path):
            return self.operations[(method, path)]["responses"]["200"]["content"]["application/json"]["schema"]

        schemas = self.document["components"]["schemas"]
        preview_ref = {"$ref": "#/components/schemas/CoursePreview"}
        outline_ref = {"$ref": "#/components/schemas/CourseOutline"}
        self.assertEqual(response_schema("post", "/courses/import"), preview_ref)
        self.assertEqual(response_schema("get", "/preview/{repoId}/{sha}"), preview_ref)
        self.assertEqual(
            response_schema("get", "/preview/{repoId}/{sha}/folders/{lessonId}/{resourceId}"),
            {"$ref": "#/components/schemas/PreviewFolder"},
        )
        self.assertEqual(response_schema("get", "/courses/{courseId}/manifest"), outline_ref)
        self.assertEqual(schemas["CoursePreview"]["properties"]["outline"], outline_ref)
        self.assertEqual(set(schemas["CoursePreview"]["properties"]), {
            "repoId", "sha", "outline", "readmePresent", "warnings",
        })
        self.assertNotIn("warnings", schemas["CoursePreview"]["required"])
        self.assertNotIn("path", schemas["OutlineResource"]["required"])

        pending = ["CoursePreview"]
        visited = set()
        while pending:
            name = pending.pop()
            if name in visited:
                continue
            visited.add(name)
            for reference in references(schemas[name]):
                self.assertTrue(reference.startswith("#/components/schemas/"), reference)
                pending.append(reference.rsplit("/", 1)[1])

        validator = Draft202012Validator(dict(preview_ref, components={"schemas": schemas}))
        sha = "a" * 40
        resource = {
            "id": "slides", "kind": "pdf", "title": "Slides",
            "href": f"/api/preview/42/{sha}/content/lesson/slides",
        }
        preview = {
            "repoId": 42, "sha": sha, "readmePresent": True,
            "outline": {
                "course": {
                    "id": "course", "title": "Course", "summary": "Summary",
                    "version": "1.0.0", "language": "en",
                },
                "nodes": [{
                    "id": "lesson", "kind": "lesson", "title": "Lesson",
                    "children": [], "resources": [resource],
                }],
                "assignments": [],
            },
        }
        validator.validate(preview)
        resource["path"] = "materials/slides.pdf"
        preview["warnings"] = [{
            "code": "cover_too_small", "message": "Use a larger cover.", "path": "images/cover.png",
        }]
        validator.validate(preview)
        del preview["warnings"][0]["path"]
        self.assertFalse(validator.is_valid(preview))
        del preview["warnings"]
        resource["href"] = "/api/courses/course/content/assignment~practice/slides"
        validator.validate(preview)
        del resource["path"]
        resource["href"] = None
        validator.validate(preview)
        del resource["href"]
        self.assertFalse(validator.is_valid(preview))


if __name__ == "__main__":
    unittest.main()
