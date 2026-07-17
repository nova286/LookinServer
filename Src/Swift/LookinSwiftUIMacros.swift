#if canImport(SwiftUI)

/// Automatically wraps a SwiftUI `View.body` with Lookin's semantic node probe.
///
/// The generated probe is active only in Debug builds. Release builds preserve
/// the original `body` result and do not reference the Lookin runtime bridge.
@attached(memberAttribute)
@attached(member, names: named(_LookinSwiftUIBodyBuilder))
public macro LookinInspectable() = #externalMacro(
    module: "LookinServerMacros",
    type: "LookinInspectableMacro"
)

#endif
