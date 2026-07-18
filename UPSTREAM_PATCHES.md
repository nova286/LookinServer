# Imported Upstream Patches

This fork incorporates selected community pull requests that were not merged by the original project. Imported commits preserve the original author whenever possible. A listed pull request remains unmerged upstream unless its status is updated here.

| Local commit | Upstream pull request | Original commit | Local adaptation |
| --- | --- | --- | --- |
| `ee11b92` | [QMUI/LookinServer#159](https://github.com/QMUI/LookinServer/pull/159) | `6db2bb1858865255f7fa6c5424d08b509a4b9190` | None. Renames the export overlay property to avoid the iOS 18 `maskView` collision. |
| `d9f34d9` | [QMUI/LookinServer#165](https://github.com/QMUI/LookinServer/pull/165) | `2377dc6cb63be48bc6aef825110e35e8a86bb9ec` | Uses an early return when running inside SwiftUI Previews. |
| `7929384` | [QMUI/LookinServer#173](https://github.com/QMUI/LookinServer/pull/173) | `cb1f9baeda8c294c758a0a131a63283efe103e8a` | Treats a null dispatch payload as zero bytes so the existing completion and error paths still run. |
| `codex/upstream-wireless` | [QMUI/LookinServer#164](https://github.com/QMUI/LookinServer/pull/164) | `4f63587`, `f33b8b4`, `6000fe1`, `6f526dd`, `1d7a5ca`, `8dabc32`, `3266602` | Paired with `nova286/Lookin#42`; preserves opt-in CocoaPods packaging, excludes wireless from the default SPM product, requires device-side confirmation, persists peer identities on both sides, bounds protocol frames, and keeps runtime UI text in English. Merge commits and the upstream default-SPM CocoaAsyncSocket dependency were intentionally excluded. |

Large or cross-repository features are ported on dedicated branches instead of being applied directly. Every imported patch must build against the fork's current default branch before it is merged.
