# Contributing

You'll need [Homebrew](https://brew.sh) and [XcodeGen](https://github.com/yonaskolb/xcodegen).

```sh
brew install xcodegen
xcodegen --version
```

Once you have all the tools ready you can clone the repository.

```sh
git clone https://code.vexcited.com/forgejo/macos-runner
```

The Xcode project is generated from `project.yml` and is intentionally ignored by Git. Regenerate it after adding, moving or removing files.

```sh
xcodegen generate
open ForgejoRunner.xcodeproj
```
