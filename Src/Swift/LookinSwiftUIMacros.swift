#if canImport(SwiftUI)

/// Automatically wraps a SwiftUI `View.body` with Lookin's semantic node probe.
///
/// The generated probe is active in Debug and explicitly opted-in Staging builds.
/// Other builds preserve the original `body` without referencing the runtime bridge.
@attached(memberAttribute)
@attached(member, names: named(_LookinSwiftUIBodyBuilder))
public macro LookinInspectable() = #externalMacro(
    module: "LookinServerMacros",
    type: "LookinInspectableMacro"
)

#endif
