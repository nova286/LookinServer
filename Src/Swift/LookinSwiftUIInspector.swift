#if SHOULD_COMPILE_LOOKIN_SERVER && canImport(SwiftUI)

import SwiftUI
import UIKit

/// An editable value displayed in Lookin's existing custom-attribute panel.
///
/// Setter blocks are retained by LookinServer for the lifetime of the current
/// hierarchy snapshot. Callers should prefer `Binding` values that don't
/// strongly retain view controllers or other short-lived objects.
@available(iOS 13.0, *)
public struct LookinSwiftUIProperty {
    fileprivate let makeRawDictionary: () -> [String: Any]

    private init(makeRawDictionary: @escaping () -> [String: Any]) {
        self.makeRawDictionary = makeRawDictionary
    }

    public static func readOnly(
        section: String = "SwiftUI",
        title: String,
        value: String
    ) -> LookinSwiftUIProperty {
        LookinSwiftUIProperty {
            [
                "section": section,
                "title": title,
                "value": value,
                "valueType": "string",
            ]
        }
    }

    public static func string(
        section: String = "SwiftUI",
        title: String,
        value: Binding<String>
    ) -> LookinSwiftUIProperty {
        LookinSwiftUIProperty {
            var property: [String: Any] = [
                "section": section,
                "title": title,
                "value": value.wrappedValue,
                "valueType": "string",
            ]
            let setter: @convention(block) (String?) -> Void = { newValue in
                lookinSetOnMain {
                    value.wrappedValue = newValue ?? ""
                }
            }
            property["retainedSetter"] = setter as AnyObject
            return property
        }
    }

    public static func number(
        section: String = "SwiftUI",
        title: String,
        value: Binding<Double>
    ) -> LookinSwiftUIProperty {
        LookinSwiftUIProperty {
            var property: [String: Any] = [
                "section": section,
                "title": title,
                "value": NSNumber(value: value.wrappedValue),
                "valueType": "number",
            ]
            let setter: @convention(block) (NSNumber) -> Void = { newValue in
                lookinSetOnMain {
                    value.wrappedValue = newValue.doubleValue
                }
            }
            property["retainedSetter"] = setter as AnyObject
            return property
        }
    }

    public static func bool(
        section: String = "SwiftUI",
        title: String,
        value: Binding<Bool>
    ) -> LookinSwiftUIProperty {
        LookinSwiftUIProperty {
            var property: [String: Any] = [
                "section": section,
                "title": title,
                "value": NSNumber(value: value.wrappedValue),
                "valueType": "bool",
            ]
            let setter: @convention(block) (Bool) -> Void = { newValue in
                lookinSetOnMain {
                    value.wrappedValue = newValue
                }
            }
            property["retainedSetter"] = setter as AnyObject
            return property
        }
    }

    public static func color(
        section: String = "SwiftUI",
        title: String,
        value: Binding<UIColor>
    ) -> LookinSwiftUIProperty {
        LookinSwiftUIProperty {
            var property: [String: Any] = [
                "section": section,
                "title": title,
                "value": value.wrappedValue,
                "valueType": "color",
            ]
            let setter: @convention(block) (UIColor?) -> Void = { newValue in
                guard let newValue = newValue else { return }
                lookinSetOnMain {
                    value.wrappedValue = newValue
                }
            }
            property["retainedSetter"] = setter as AnyObject
            return property
        }
    }

    public static func enumeration(
        section: String = "SwiftUI",
        title: String,
        value: Binding<String>,
        cases: [String]
    ) -> LookinSwiftUIProperty {
        LookinSwiftUIProperty {
            var property: [String: Any] = [
                "section": section,
                "title": title,
                "value": value.wrappedValue,
                "valueType": "enum",
                "allEnumCases": cases,
            ]
            let setter: @convention(block) (String) -> Void = { newValue in
                guard cases.contains(newValue) else { return }
                lookinSetOnMain {
                    value.wrappedValue = newValue
                }
            }
            property["retainedSetter"] = setter as AnyObject
            return property
        }
    }
}

@available(iOS 13.0, *)
public extension View {
    /// Installs the bridge that exposes registered SwiftUI nodes to Lookin.
    /// Add this once near the root of each inspected SwiftUI hierarchy.
    func lookinSwiftUIInspector(title: String = "SwiftUI") -> some View {
        modifier(LookinSwiftUIInspectorRootModifier(title: title))
    }

    /// Registers a semantic SwiftUI node under the nearest inspector root.
    ///
    /// `id` must be stable and unique within the inspector root. Children
    /// automatically inherit this node as their semantic parent. Use
    /// `parentID` only when the SwiftUI composition does not reflect the
    /// hierarchy you want Lookin to display.
    func lookinInspectable(
        id: String,
        title: String? = nil,
        parentID: String? = nil,
        properties: [LookinSwiftUIProperty] = [],
        fileID: StaticString = #fileID,
        line: UInt = #line
    ) -> some View {
        modifier(
            LookinSwiftUINodeModifier(
                id: id,
                title: title ?? String(describing: Self.self),
                explicitParentID: parentID,
                source: "\(String(describing: fileID)):\(line)",
                properties: properties
            )
        )
    }
}

@available(iOS 13.0, *)
private struct LookinSwiftUIRegistryKey: EnvironmentKey {
    static let defaultValue: LookinSwiftUIRegistry? = nil
}

@available(iOS 13.0, *)
private struct LookinSwiftUIParentIDKey: EnvironmentKey {
    static let defaultValue: String? = nil
}

@available(iOS 13.0, *)
private extension EnvironmentValues {
    var lookinSwiftUIRegistry: LookinSwiftUIRegistry? {
        get { self[LookinSwiftUIRegistryKey.self] }
        set { self[LookinSwiftUIRegistryKey.self] = newValue }
    }

    var lookinSwiftUIParentID: String? {
        get { self[LookinSwiftUIParentIDKey.self] }
        set { self[LookinSwiftUIParentIDKey.self] = newValue }
    }
}

@available(iOS 13.0, *)
private struct LookinSwiftUIInspectorRootModifier: ViewModifier {
    let title: String
    @State private var registry = LookinSwiftUIRegistry()

    func body(content: Content) -> some View {
        content
            .environment(\.lookinSwiftUIRegistry, registry)
            .environment(\.lookinSwiftUIParentID, nil)
            .background(
                LookinSwiftUIRootProbe(registry: registry, title: title)
                    .allowsHitTesting(false)
            )
    }
}

@available(iOS 13.0, *)
private struct LookinSwiftUINodeModifier: ViewModifier {
    let id: String
    let title: String
    let explicitParentID: String?
    let source: String
    let properties: [LookinSwiftUIProperty]

    @Environment(\.lookinSwiftUIRegistry) private var registry
    @Environment(\.lookinSwiftUIParentID) private var inheritedParentID

    func body(content: Content) -> some View {
        content
            .environment(\.lookinSwiftUIParentID, id)
            .background(
                Group {
                    if let registry = registry {
                        LookinSwiftUINodeProbe(
                            registry: registry,
                            id: id,
                            parentID: explicitParentID ?? inheritedParentID,
                            title: title,
                            source: source,
                            properties: properties
                        )
                        .allowsHitTesting(false)
                    }
                }
            )
    }
}

@available(iOS 13.0, *)
private struct LookinSwiftUIRootProbe: UIViewRepresentable {
    let registry: LookinSwiftUIRegistry
    let title: String

    func makeUIView(context: Context) -> LookinSwiftUIRootProbeView {
        LookinSwiftUIRootProbeView(registry: registry, title: title)
    }

    func updateUIView(_ uiView: LookinSwiftUIRootProbeView, context: Context) {
        uiView.registry = registry
        uiView.inspectorTitle = title
    }
}

@available(iOS 13.0, *)
private final class LookinSwiftUIRootProbeView: UIView {
    var registry: LookinSwiftUIRegistry
    var inspectorTitle: String

    init(registry: LookinSwiftUIRegistry, title: String) {
        self.registry = registry
        inspectorTitle = title
        super.init(frame: .zero)
        backgroundColor = .clear
        isUserInteractionEnabled = false
        accessibilityElementsHidden = true
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    @objc(lookin_customDebugInfos_4)
    func lookinCustomDebugInfos() -> [String: Any]? {
        guard let window = window else { return nil }
        let subviews = registry.rawSubviews(in: window)
        var semanticRoot: [String: Any] = [
            "title": inspectorTitle,
            "subtitle": "SwiftUI Semantic Hierarchy",
            "semanticKind": "swiftui-root",
            "properties": [
                [
                    "section": "SwiftUI",
                    "title": "Root Nodes",
                    "value": NSNumber(value: subviews.count),
                    "valueType": "number",
                ],
            ],
            "subviews": subviews,
        ]
        semanticRoot["frameInWindow"] = NSValue(cgRect: convert(bounds, to: window))
        return [
            "title": inspectorTitle,
            "subviews": [semanticRoot],
        ]
    }
}

@available(iOS 13.0, *)
private struct LookinSwiftUINodeProbe: UIViewRepresentable {
    let registry: LookinSwiftUIRegistry
    let id: String
    let parentID: String?
    let title: String
    let source: String
    let properties: [LookinSwiftUIProperty]

    func makeUIView(context: Context) -> LookinSwiftUINodeProbeView {
        let view = LookinSwiftUINodeProbeView()
        update(view)
        return view
    }

    func updateUIView(_ uiView: LookinSwiftUINodeProbeView, context: Context) {
        update(uiView)
    }

    static func dismantleUIView(_ uiView: LookinSwiftUINodeProbeView, coordinator: ()) {
        uiView.unregister()
    }

    private func update(_ view: LookinSwiftUINodeProbeView) {
        view.configure(
            registry: registry,
            id: id,
            parentID: parentID,
            title: title,
            source: source,
            properties: properties
        )
    }
}

@available(iOS 13.0, *)
private final class LookinSwiftUINodeProbeView: UIView {
    private weak var registry: LookinSwiftUIRegistry?
    private var nodeID: String?

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .clear
        isUserInteractionEnabled = false
        accessibilityElementsHidden = true
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func configure(
        registry: LookinSwiftUIRegistry,
        id: String,
        parentID: String?,
        title: String,
        source: String,
        properties: [LookinSwiftUIProperty]
    ) {
        if nodeID != id || self.registry !== registry {
            unregister()
        }
        self.registry = registry
        nodeID = id
        registry.upsert(
            id: id,
            parentID: parentID,
            title: title,
            source: source,
            properties: properties,
            probeView: self
        )
    }

    func unregister() {
        guard let registry = registry, let nodeID = nodeID else { return }
        registry.remove(id: nodeID, probeView: self)
        self.registry = nil
        self.nodeID = nil
    }

    deinit {
        unregister()
    }
}

@available(iOS 13.0, *)
private final class LookinSwiftUIRegistry {
    private final class Entry {
        let id: String
        let order: UInt
        weak var probeView: UIView?
        var parentID: String?
        var title: String
        var source: String
        var properties: [LookinSwiftUIProperty]

        init(
            id: String,
            order: UInt,
            probeView: UIView,
            parentID: String?,
            title: String,
            source: String,
            properties: [LookinSwiftUIProperty]
        ) {
            self.id = id
            self.order = order
            self.probeView = probeView
            self.parentID = parentID
            self.title = title
            self.source = source
            self.properties = properties
        }
    }

    private var entries: [String: Entry] = [:]
    private var nextOrder: UInt = 0

    func upsert(
        id: String,
        parentID: String?,
        title: String,
        source: String,
        properties: [LookinSwiftUIProperty],
        probeView: UIView
    ) {
        if let entry = entries[id] {
            entry.probeView = probeView
            entry.parentID = parentID
            entry.title = title
            entry.source = source
            entry.properties = properties
            return
        }

        nextOrder += 1
        entries[id] = Entry(
            id: id,
            order: nextOrder,
            probeView: probeView,
            parentID: parentID,
            title: title,
            source: source,
            properties: properties
        )
    }

    func remove(id: String, probeView: UIView) {
        guard entries[id]?.probeView === probeView else { return }
        entries[id] = nil
    }

    func rawSubviews(in window: UIWindow) -> [[String: Any]] {
        entries = entries.filter { $0.value.probeView != nil }

        let activeEntries = entries.values
            .filter { $0.probeView?.window === window }
            .sorted { $0.order < $1.order }
        let activeIDs = Set(activeEntries.map { $0.id })
        var roots: [Entry] = []
        var childrenByParentID: [String: [Entry]] = [:]

        for entry in activeEntries {
            if let parentID = entry.parentID,
               parentID != entry.id,
               activeIDs.contains(parentID) {
                childrenByParentID[parentID, default: []].append(entry)
            } else {
                roots.append(entry)
            }
        }

        return roots.map {
            rawDictionary(
                for: $0,
                in: window,
                childrenByParentID: childrenByParentID,
                visited: []
            )
        }
    }

    private func rawDictionary(
        for entry: Entry,
        in window: UIWindow,
        childrenByParentID: [String: [Entry]],
        visited: Set<String>
    ) -> [String: Any] {
        var nextVisited = visited
        nextVisited.insert(entry.id)

        var properties: [[String: Any]] = [
            [
                "section": "SwiftUI",
                "title": "ID",
                "value": entry.id,
                "valueType": "string",
            ],
            [
                "section": "SwiftUI",
                "title": "Type",
                "value": entry.title,
                "valueType": "string",
            ],
            [
                "section": "SwiftUI",
                "title": "Source",
                "value": entry.source,
                "valueType": "string",
            ],
        ]
        properties.append(contentsOf: entry.properties.map { $0.makeRawDictionary() })

        var dictionary: [String: Any] = [
            "title": entry.title,
            "subtitle": entry.source,
            "properties": properties,
            "lookin_source": entry.source,
        ]

        if let probeView = entry.probeView {
            let frame = probeView.convert(probeView.bounds, to: window)
            dictionary["frameInWindow"] = NSValue(cgRect: frame)
        }

        let children = (childrenByParentID[entry.id] ?? [])
            .filter { !nextVisited.contains($0.id) }
            .map {
                rawDictionary(
                    for: $0,
                    in: window,
                    childrenByParentID: childrenByParentID,
                    visited: nextVisited
                )
            }
        if !children.isEmpty {
            dictionary["subviews"] = children
        }

        return dictionary
    }
}

private func lookinSetOnMain(_ update: @escaping () -> Void) {
    if Thread.isMainThread {
        update()
    } else {
        DispatchQueue.main.async(execute: update)
    }
}

#endif /* SHOULD_COMPILE_LOOKIN_SERVER && canImport(SwiftUI) */
