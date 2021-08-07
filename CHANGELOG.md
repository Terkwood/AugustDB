# Changelog

All notable changes to this project will be documented in this file. See [standard-version](https://github.com/conventional-changelog/standard-version) for commit guidelines.

### [0.4.1](https://github.com/Terkwood/AugustDB/compare/v0.4.0...v0.4.1) (2021-08-07)


### Features

* write and verify checksum in commit.log ([#87](https://github.com/Terkwood/AugustDB/issues/87)) ([bc0d7e3](https://github.com/Terkwood/AugustDB/commit/bc0d7e351bf20d2928aa2b8af987a2ef638826ea))


### Bug Fixes

* discard malformed entries in commit.log ([#86](https://github.com/Terkwood/AugustDB/issues/86)) ([f95e790](https://github.com/Terkwood/AugustDB/commit/f95e790c577a54a6f9ae3e9e269463da50334e6c))

## [0.4.0](https://github.com/Terkwood/AugustDB/compare/v0.3.0...v0.4.0) (2021-08-06)


### ⚠ BREAKING CHANGES

* compress SSTables (#81)

### Features

* compress SSTables ([#81](https://github.com/Terkwood/AugustDB/issues/81)) ([e0e8b55](https://github.com/Terkwood/AugustDB/commit/e0e8b551f36dc7cff9968770ecad3d2a3a014152))
* create and verify checksums ([#79](https://github.com/Terkwood/AugustDB/issues/79)) ([a091db3](https://github.com/Terkwood/AugustDB/commit/a091db39e9f9644dad8d5092dedf624d2ef5b7c5))

## [0.3.0](https://github.com/Terkwood/AugustDB/compare/v0.2.0...v0.3.0) (2021-08-04)


### ⚠ BREAKING CHANGES

* use sparse index on SSTables (#74)

### Features

* keep sparse SSTable indices in memory ([#76](https://github.com/Terkwood/AugustDB/issues/76)) ([212f506](https://github.com/Terkwood/AugustDB/commit/212f5062e7088a81b4a75437594dfd8cc84a3f51))
* use sparse index on SSTables ([#74](https://github.com/Terkwood/AugustDB/issues/74)) ([5c17d7d](https://github.com/Terkwood/AugustDB/commit/5c17d7df873b83fbb603f2693fb71208841c4c52))


### Bug Fixes

* gag stdout when compaction is no-op ([1e994aa](https://github.com/Terkwood/AugustDB/commit/1e994aafd985af9f61665a4cbc52defd65b036ca))

## [0.2.0](https://github.com/Terkwood/AugustDB/compare/v0.1.1...v0.2.0) (2021-08-03)


### ⚠ BREAKING CHANGES

* binary SSTable format (#68)

### Features

* binary SSTable format ([#68](https://github.com/Terkwood/AugustDB/issues/68)) ([8f1f8aa](https://github.com/Terkwood/AugustDB/commit/8f1f8aa732b7e10496a656ac5c7b842dac1bb10d))


### Bug Fixes

* tombstone binary rep, write commit log on del ([#70](https://github.com/Terkwood/AugustDB/issues/70)) ([c9ceb68](https://github.com/Terkwood/AugustDB/commit/c9ceb68330c4e2832b864b6887e00c12ff95e387))

### [0.1.1](https://github.com/Terkwood/AugustDB/compare/v0.1.0...v0.1.1) (2021-08-01)


### Features

* touch commit log on startup ([#67](https://github.com/Terkwood/AugustDB/issues/67)) ([c5d3043](https://github.com/Terkwood/AugustDB/commit/c5d304325d47d3c3b919454f01fa4df43a2a8fe2))

## 0.1.0 (2021-08-01)


### Features

* append to commit log ([#42](https://github.com/Terkwood/AugustDB/issues/42)) ([bed9452](https://github.com/Terkwood/AugustDB/commit/bed9452a3623d81437c221d527cec2a7d4a4405a))
* current and flushing memtable ([#28](https://github.com/Terkwood/AugustDB/issues/28)) ([d51acc7](https://github.com/Terkwood/AugustDB/commit/d51acc733d90b1fa84b80e91c1c6c412d138eedb))
* delete old files after compaction ([488d4dd](https://github.com/Terkwood/AugustDB/commit/488d4dd2fbe387bb7ba2956064c2ce6c260a7059))
* dump key/vals to SSTable ([#1](https://github.com/Terkwood/AugustDB/issues/1)) ([ccb6230](https://github.com/Terkwood/AugustDB/commit/ccb62308d3a5a5a7eb2ae8e60acfdbb750cf4f0c))
* flush memtable on startup ([#65](https://github.com/Terkwood/AugustDB/issues/65)) ([3060a6f](https://github.com/Terkwood/AugustDB/commit/3060a6f8794d0a252f7dea8f342a0ac3f267832d))
* flush the memtable ([#29](https://github.com/Terkwood/AugustDB/issues/29)) ([acbbb20](https://github.com/Terkwood/AugustDB/commit/acbbb2094145b273bc44ddac7147dc87ca5d3f02))
* GET and PUT stubs ([#5](https://github.com/Terkwood/AugustDB/issues/5)) ([8f24949](https://github.com/Terkwood/AugustDB/commit/8f249495902e8316f40b0899eea55c0148c4ae7e))
* HTTP DELETE ([#27](https://github.com/Terkwood/AugustDB/issues/27)) ([e6832c9](https://github.com/Terkwood/AugustDB/commit/e6832c985fb040aff3835e749a1d61eeddf08f85))
* HTTP GET ([#26](https://github.com/Terkwood/AugustDB/issues/26)) ([df90598](https://github.com/Terkwood/AugustDB/commit/df905986f88a5a2d3c0156a1dfd29c6e32544509))
* HTTP PUT ([#23](https://github.com/Terkwood/AugustDB/issues/23)) ([e0cdd8d](https://github.com/Terkwood/AugustDB/commit/e0cdd8d261359ab238c4d24e21ee8f1ec3b7eb17))
* memtable ([#22](https://github.com/Terkwood/AugustDB/issues/22)) ([ef2e312](https://github.com/Terkwood/AugustDB/commit/ef2e3124e9b08dbc799c74e62da739150b65ca0c))
* periodic compaction ([01fad09](https://github.com/Terkwood/AugustDB/commit/01fad099c99e9c86ceee35f4d2d34cf13864e13a))
* query all SSTables ([#44](https://github.com/Terkwood/AugustDB/issues/44)) ([75ae07d](https://github.com/Terkwood/AugustDB/commit/75ae07d4c19f52962409340ba163819cdbd69833))
* query SSTable file ([#31](https://github.com/Terkwood/AugustDB/issues/31)) ([81484fe](https://github.com/Terkwood/AugustDB/commit/81484fe50f91126a6379f3bf6c330b8ca0ad60a7))
* query sstables in web layer ([#58](https://github.com/Terkwood/AugustDB/issues/58)) ([3485daf](https://github.com/Terkwood/AugustDB/commit/3485dafe391b2411d6c936fd34904648dbb783d9))
* replay commit log ([#43](https://github.com/Terkwood/AugustDB/issues/43)) ([7105255](https://github.com/Terkwood/AugustDB/commit/7105255bde60d221da5abef890832823d81193ed))
* replay commitlog on startup ([8958238](https://github.com/Terkwood/AugustDB/commit/89582383e5b8c7f54a4b2394af15054394015fc0))
* return 204 for PUT ([691d272](https://github.com/Terkwood/AugustDB/commit/691d272076bb568b21ecc4cf9fd18406db0c82d5))
* return explicit tombstone in sstable query ([#37](https://github.com/Terkwood/AugustDB/issues/37)) ([f22e096](https://github.com/Terkwood/AugustDB/commit/f22e096cd00a9089f62017e57b10b5cdbf7d0b94))
* rm commit log on memtable flush ([#57](https://github.com/Terkwood/AugustDB/issues/57)) ([58a0042](https://github.com/Terkwood/AugustDB/commit/58a0042a67237ef054b1faa4e18af4fc51201433))
* seek to key-value in file ([#6](https://github.com/Terkwood/AugustDB/issues/6)) ([06b870d](https://github.com/Terkwood/AugustDB/commit/06b870d80990b5222629fa0b31a02925403caf9c))
* SSTable compaction ([#59](https://github.com/Terkwood/AugustDB/issues/59)) ([5592c2a](https://github.com/Terkwood/AugustDB/commit/5592c2ab4fe1ee6b38d564b84ec8ab054f43daae))
* track memtable size ([#64](https://github.com/Terkwood/AugustDB/issues/64)) ([a52475a](https://github.com/Terkwood/AugustDB/commit/a52475a03b0c50170602658fd21641f37196f888))
* write tombstone in SSTable ([#34](https://github.com/Terkwood/AugustDB/issues/34)) ([77fa6c2](https://github.com/Terkwood/AugustDB/commit/77fa6c20aae674f3ac97e3d8b294c68f05f402a4))


### Bug Fixes

* add compaction bottom cases ([95b7e27](https://github.com/Terkwood/AugustDB/commit/95b7e2797398569005c210f47223bc64f4a14c8c))
* CSV header wrt index ([7d419c7](https://github.com/Terkwood/AugustDB/commit/7d419c738695b00be7acbaf86f25c8d9b8fb2d97))
* dump CSV header ([2d17f68](https://github.com/Terkwood/AugustDB/commit/2d17f6826990ab6cdc0c8a74f9b8042ab2339a9a))
* read ahead during SSTable seek ([0fe8497](https://github.com/Terkwood/AugustDB/commit/0fe84976c95da0597402019fca2bda990d905195))
* remove damaged spec ([e1e53a7](https://github.com/Terkwood/AugustDB/commit/e1e53a7d957ab97527e4aa4199f3e7169d652caa))
* represent sstable index as map ([#63](https://github.com/Terkwood/AugustDB/issues/63)) ([686e420](https://github.com/Terkwood/AugustDB/commit/686e420f0fdab9e7e36f26d9faf9a9efbf58ba71))
* rewrite sstable index ([4e44087](https://github.com/Terkwood/AugustDB/commit/4e44087a66dafe470068981236866e15fd94e3e7))
* split out table and index ([bc13cd2](https://github.com/Terkwood/AugustDB/commit/bc13cd2f655d310c3226150bfca719249310fa6f))
* tune compaction period ([4246974](https://github.com/Terkwood/AugustDB/commit/4246974151f3f033903f7751a8ea23a4c4f2434f))
* unescape string in GET ([#47](https://github.com/Terkwood/AugustDB/issues/47)) ([8725b43](https://github.com/Terkwood/AugustDB/commit/8725b43d5d90310b95dd5a7b792f9f5f0b7d770f))
* update dump spec ([fcfada0](https://github.com/Terkwood/AugustDB/commit/fcfada06d6bac8be87dc6544f0c19a40a25a254d))
* use pread in file seek, alter return type ([#7](https://github.com/Terkwood/AugustDB/issues/7)) ([5fde049](https://github.com/Terkwood/AugustDB/commit/5fde049955906e651062178e148a990930df4ab4))
