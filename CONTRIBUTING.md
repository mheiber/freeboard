# Contributing

## Setup

1. Clone the repo
2. Open in Xcode or build from command line (see [README](README.md))
3. Grant Accessibility permissions when prompted

## Making Changes

- Read [AGENTS.md](AGENTS.md) for architecture and conventions
- No disk, no network — keep everything in-memory and local
- Add tests for new logic in `FreeboardTests/`
- Run the full test suite before submitting

## Adding Source Files

The Xcode project is hand-maintained. When adding a `.swift` file:

1. Add the file to `Freeboard/` or `FreeboardTests/`
2. Add a `PBXFileReference` entry in `project.pbxproj`
3. Add a `PBXBuildFile` entry and reference it in the appropriate `PBXSourcesBuildPhase`
4. For testable logic files, also add them to the test target's sources phase
