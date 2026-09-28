Forgejo Runner is a native macOS app that runs Forgejo Actions jobs inside disposable Apple-silicon VMs. Each job gets a fresh clone of a golden [Tart](https://tart.run) image, and that clone is deleted as soon as the job ends.

## Requirements

- An Apple-silicon Mac running macOS 15 or newer.
- [Tart](https://tart.run) and [Softnet](https://github.com/openai/softnet) 0.22.0 or newer, installed with Homebrew.

## Getting Started

1. Install required tools.

   ```bash
   brew install openai/tools/tart
   ```

2. Download the latest `ForgejoRunner-<version>.dmg` from the [releases](https://code.vexcited.com/forgejo/macos-runner/releases), open it, drag Forgejo Runner into Applications and open it from there.

3. The first launch walks you through the setup, one step at a time. Once done you can start the runner.

4. Target the label from a Forgejo workflow, to see if it works!

   ```yaml
   jobs:
     build:
       runs-on: macos-latest # depends on the label you choose!
       steps:
         - uses: actions/checkout@v7
         - run: xcodebuild -version
   ```

## FAQ

For anything not covered here, please [open an issue](https://code.vexcited.com/forgejo/macos-runner/issues).
