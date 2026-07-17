import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros

public struct LookinInspectableMacro: MemberAttributeMacro, MemberMacro {
    private static let builderName = "_LookinSwiftUIBodyBuilder"

    public static func expansion(
        of node: AttributeSyntax,
        attachedTo declaration: some DeclGroupSyntax,
        providingAttributesFor member: some DeclSyntaxProtocol,
        in context: some MacroExpansionContext
    ) throws -> [AttributeSyntax] {
        guard isBodyProperty(member) else { return [] }
        return [AttributeSyntax(stringLiteral: "@\(builderName)")]
    }

    public static func expansion(
        of node: AttributeSyntax,
        providingMembersOf declaration: some DeclGroupSyntax,
        conformingTo protocols: [TypeSyntax],
        in context: some MacroExpansionContext
    ) throws -> [DeclSyntax] {
        guard declaration.memberBlock.members.contains(where: { isBodyProperty($0.decl) }) else {
            throw MacroExpansionErrorMessage(
                "@LookinInspectable requires a 'var body: some View' property"
            )
        }

        guard let typeName = declarationName(declaration) else {
            throw MacroExpansionErrorMessage(
                "@LookinInspectable can only be attached to a named type"
            )
        }

        return [
            DeclSyntax(stringLiteral: builderDeclaration(typeName: typeName))
        ]
    }

    private static func isBodyProperty(_ declaration: some DeclSyntaxProtocol) -> Bool {
        guard let variable = declaration.as(VariableDeclSyntax.self) else { return false }
        return variable.bindings.contains { binding in
            binding.pattern.as(IdentifierPatternSyntax.self)?.identifier.text == "body"
        }
    }

    private static func declarationName(_ declaration: some DeclGroupSyntax) -> String? {
        if let declaration = declaration.as(StructDeclSyntax.self) {
            return declaration.name.text
        }
        if let declaration = declaration.as(ClassDeclSyntax.self) {
            return declaration.name.text
        }
        if let declaration = declaration.as(ActorDeclSyntax.self) {
            return declaration.name.text
        }
        return nil
    }

    private static func builderDeclaration(typeName: String) -> String {
        """
        @resultBuilder
        private enum \(builderName) {
            static func buildExpression<LookinBuiltContent: View>(
                _ content: LookinBuiltContent
            ) -> LookinBuiltContent {
                content
            }

            static func buildBlock() -> EmptyView {
                EmptyView()
            }

            static func buildBlock<LookinBuiltContent: View>(
                _ content: LookinBuiltContent
            ) -> LookinBuiltContent {
                content
            }

            static func buildBlock<each LookinBuiltContent: View>(
                _ content: repeat each LookinBuiltContent
            ) -> TupleView<(repeat each LookinBuiltContent)> {
                ViewBuilder.buildBlock(repeat each content)
            }

            static func buildIf<LookinBuiltContent: View>(
                _ content: LookinBuiltContent?
            ) -> LookinBuiltContent? {
                content
            }

            static func buildEither<LookinTrueContent: View, LookinFalseContent: View>(
                first: LookinTrueContent
            ) -> _ConditionalContent<LookinTrueContent, LookinFalseContent> {
                ViewBuilder.buildEither(first: first)
            }

            static func buildEither<LookinTrueContent: View, LookinFalseContent: View>(
                second: LookinFalseContent
            ) -> _ConditionalContent<LookinTrueContent, LookinFalseContent> {
                ViewBuilder.buildEither(second: second)
            }

            static func buildLimitedAvailability<LookinBuiltContent: View>(
                _ content: LookinBuiltContent
            ) -> AnyView {
                AnyView(content)
            }

            static func buildFinalResult<LookinBuiltContent: View>(
                _ component: LookinBuiltContent
            ) -> some View {
        #if DEBUG
                component._lookinAutomaticallyInspectable(
                    title: "\(typeName)",
                    fileID: #fileID,
                    line: #line
                )
        #else
                component
        #endif
            }
        }
        """
    }
}
