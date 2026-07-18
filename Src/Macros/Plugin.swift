import SwiftCompilerPlugin
import SwiftSyntaxMacros

@main
struct LookinServerMacroPlugin: CompilerPlugin {
    let providingMacros: [Macro.Type] = [
        LookinInspectableMacro.self,
    ]
}
