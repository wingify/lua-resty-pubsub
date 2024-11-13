# Changelog
All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.5] - 2023-11-13
### Added
- Added support for ordering key while publishing message

## [1.4] - 2021-04-17
### Fixed
- Added exception handling in push_batch method for releasing lock

## [1.3] - 2020-10-13
### Added
- Added support for accepting v1.1 config architecture thereby ensuring backward compatibility

## [1.2] - 2020-09-28
### Breaking Change
- Now the structure for providing Pub/Sub producer config is entirely changed and unified. Please refer to documentation for new schema

### Fixed
- Improved exception handling in oath_client and request Module

### Added
- Added support for publishing messages to Pub/Sub emulator

## [1.1] - 2020-04-24
### Changed
- Improved checks on input data provided to the producer module

## [1.0] - 2020-04-01
### Added
- First release with publishing messages to Google Cloud Pub/Sub capabilities
