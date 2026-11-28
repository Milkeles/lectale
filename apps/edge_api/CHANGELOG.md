# Changelog

## [0.2.0](https://github.com/Milkeles/lectale/compare/edge-api-v0.1.0...edge-api-v0.2.0) (2026-11-28)


### Features

* **contract:** add the server-side course.yaml validator ([652ce1c](https://github.com/Milkeles/lectale/commit/652ce1c3f5bc8419475da5fca19f787aff839730))
* **contract:** give clients a CourseOutline DTO and a generated Dart client ([53d50cb](https://github.com/Milkeles/lectale/commit/53d50cb1cfff5e39d40d0ba7db4b3477e1a31e84))
* **edge:** read GitHub with a scoped App installation token ([43a1071](https://github.com/Milkeles/lectale/commit/43a1071784128fff15287a4f83f26db503d50b97))
* **preview:** add resource paths and cover checks to the outline ([32d7dbe](https://github.com/Milkeles/lectale/commit/32d7dbe7dd77ee9c0ae1532a14148ba019130f80))
* **preview:** add the anonymous course preview API ([353467a](https://github.com/Milkeles/lectale/commit/353467ab7a77a4f2fc7748cefdb1f7db57201a86))
* **site:** serve the landing page at / and the app under /app ([37738bf](https://github.com/Milkeles/lectale/commit/37738bf45f971fb65e3babd7b816e61efb027659))


### Fixes

* **agents:** close guard and rule-check gaps from the Codex review ([5e0eb3e](https://github.com/Milkeles/lectale/commit/5e0eb3ebe6e821b521992c2d9d543e4b8dfd620d))
* **contract:** bound validator work and canonicalise video URLs ([c1126d8](https://github.com/Milkeles/lectale/commit/c1126d88c0b1e1e3a8b340c36e472142c5753c4e))
* **edge:** let a throttled cover read answer 429, not a cover warning ([37986a2](https://github.com/Milkeles/lectale/commit/37986a272621f8c97d1e50def06e63b0696c8510))
* **edge:** retry anonymously only when GitHub rejects the token ([aeac874](https://github.com/Milkeles/lectale/commit/aeac874ff98c916230cad6a06df6bef27da9d6e8))
* **preview:** bind pins to their repository and close review findings ([696664a](https://github.com/Milkeles/lectale/commit/696664a16709ef49d2d711e459d26058655cbfa7))
* **preview:** close the remaining findings from both verifications ([948f85c](https://github.com/Milkeles/lectale/commit/948f85c5cfa365eeea77e1ec199d0e27b0ec43fe))


### Performance

* **contract:** compile the course schema with Ajv at build time ([9893881](https://github.com/Milkeles/lectale/commit/9893881729e77a6224ef8468f6c3e2fbd9028be1))
