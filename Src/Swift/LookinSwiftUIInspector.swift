#if SHOULD_COMPILE_LOOKIN_SERVER && canImport(SwiftUI)

import Darwin
import Foundation
import SwiftUI
import UIKit

/// Enables SwiftUI's rendered debug tree. Call this before the first hosting
/// view is created (normally from the app's `App.init`).
@available(iOS 13.0, *)
public enum LookinSwiftUIInspector {
    public static func prepareRuntimeTreeCapture() {
        setenv("SWIFTUI_VIEW_DEBUG", "287", 1)
    }
}

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
    func lookinSwiftUIInspector(
        title: String = "SwiftUI",
        includeRuntimeNodes: Bool = false
    ) -> some View {
        modifier(
            LookinSwiftUIInspectorRootModifier(
                title: title,
                includeRuntimeNodes: includeRuntimeNodes
            )
        )
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

    /// Used by `@LookinInspectable` macro expansions. Callers should prefer
    /// the macro or the public `lookinInspectable` modifier.
    func _lookinAutomaticallyInspectable(
        title: String,
        fileID: StaticString,
        line: UInt
    ) -> some View {
        modifier(
            LookinSwiftUIAutomaticNodeModifier(
                title: title,
                source: "\(String(describing: fileID)):\(line)"
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
public extension EnvironmentValues {
    /// Registers the concrete `UIView` created by a `UIViewRepresentable` as a
    /// semantic child of the nearest SwiftUI inspector node. Call this from
    /// both `makeUIView` and `updateUIView` so a late-installed inspector root
    /// can still discover the representable.
    @MainActor
    @discardableResult
    func lookinRegisterRepresentableHierarchy(
        _ rootView: UIView,
        title: String,
        fileID: StaticString = #fileID,
        line: UInt = #line
    ) -> String? {
        guard let registry = lookinSwiftUIRegistry else { return nil }
        let identity = String(describing: ObjectIdentifier(rootView))
        let id = "lookin.representable.\(title).\(identity)"
        registry.upsert(
            id: id,
            parentID: lookinSwiftUIParentID,
            title: title,
            source: "\(String(describing: fileID)):\(line)",
            properties: [],
            probeView: rootView,
            includesUIKitHierarchy: true
        )
        return id
    }

    /// Applies the current inspector registry to SwiftUI content hosted by a
    /// manually-created `UIHostingController`.
    @MainActor
    func lookinAttachInspectorContext<Content: View>(
        to content: Content
    ) -> AnyView {
        guard let registry = lookinSwiftUIRegistry else { return AnyView(content) }
        return AnyView(
            content
                .environment(\.lookinSwiftUIRegistry, registry)
                .environment(\.lookinSwiftUIParentID, lookinSwiftUIParentID)
        )
    }
}

@available(iOS 13.0, *)
private struct LookinSwiftUIInspectorRootModifier: ViewModifier {
    let title: String
    let includeRuntimeNodes: Bool
    @State private var registry = LookinSwiftUIRegistry()

    func body(content: Content) -> some View {
        content
            .environment(\.lookinSwiftUIRegistry, registry)
            .environment(\.lookinSwiftUIParentID, nil)
            .background(
                LookinSwiftUIRootProbe(
                    registry: registry,
                    title: title,
                    includeRuntimeNodes: includeRuntimeNodes
                )
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
    @State private var debugWidth = 0.0
    @State private var debugHeight = 0.0
    @State private var debugOffsetX = 0.0
    @State private var debugOffsetY = 0.0
    @State private var debugScale = 1.0
    @State private var debugIsHidden = false
    @State private var debugOpacity = 1.0
    @State private var debugBackgroundColor = UIColor.clear

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
                            properties: properties + debugOverrideProperties
                        )
                        .allowsHitTesting(false)
                    }
                }
            )
            .modifier(debugOverridesModifier)
    }

    private var debugOverrideProperties: [LookinSwiftUIProperty] {
        lookinSwiftUIDebugOverrideProperties(
            width: $debugWidth,
            height: $debugHeight,
            offsetX: $debugOffsetX,
            offsetY: $debugOffsetY,
            scale: $debugScale,
            isHidden: $debugIsHidden,
            opacity: $debugOpacity,
            backgroundColor: $debugBackgroundColor
        )
    }

    private var debugOverridesModifier: LookinSwiftUIDebugOverridesModifier {
        LookinSwiftUIDebugOverridesModifier(
            width: debugWidth,
            height: debugHeight,
            offsetX: debugOffsetX,
            offsetY: debugOffsetY,
            scale: debugScale,
            isHidden: debugIsHidden,
            opacity: debugOpacity,
            backgroundColor: debugBackgroundColor
        )
    }
}

@available(iOS 13.0, *)
private struct LookinSwiftUIAutomaticNodeModifier: ViewModifier {
    let title: String
    let source: String

    @Environment(\.lookinSwiftUIRegistry) private var registry
    @Environment(\.lookinSwiftUIParentID) private var inheritedParentID
    @State private var instanceID = UUID().uuidString
    @State private var debugWidth = 0.0
    @State private var debugHeight = 0.0
    @State private var debugOffsetX = 0.0
    @State private var debugOffsetY = 0.0
    @State private var debugScale = 1.0
    @State private var debugIsHidden = false
    @State private var debugOpacity = 1.0
    @State private var debugBackgroundColor = UIColor.clear

    func body(content: Content) -> some View {
        let id = "lookin.macro.\(title).\(instanceID)"
        content
            .environment(\.lookinSwiftUIParentID, id)
            .background(
                Group {
                    if let registry = registry {
                        LookinSwiftUINodeProbe(
                            registry: registry,
                            id: id,
                            parentID: inheritedParentID,
                            title: title,
                            source: source,
                            properties: debugOverrideProperties
                        )
                        .allowsHitTesting(false)
                    }
                }
            )
            .modifier(debugOverridesModifier)
    }

    private var debugOverrideProperties: [LookinSwiftUIProperty] {
        lookinSwiftUIDebugOverrideProperties(
            width: $debugWidth,
            height: $debugHeight,
            offsetX: $debugOffsetX,
            offsetY: $debugOffsetY,
            scale: $debugScale,
            isHidden: $debugIsHidden,
            opacity: $debugOpacity,
            backgroundColor: $debugBackgroundColor
        )
    }

    private var debugOverridesModifier: LookinSwiftUIDebugOverridesModifier {
        LookinSwiftUIDebugOverridesModifier(
            width: debugWidth,
            height: debugHeight,
            offsetX: debugOffsetX,
            offsetY: debugOffsetY,
            scale: debugScale,
            isHidden: debugIsHidden,
            opacity: debugOpacity,
            backgroundColor: debugBackgroundColor
        )
    }
}

@available(iOS 13.0, *)
private struct LookinSwiftUIDebugOverridesModifier: ViewModifier {
    let width: Double
    let height: Double
    let offsetX: Double
    let offsetY: Double
    let scale: Double
    let isHidden: Bool
    let opacity: Double
    let backgroundColor: UIColor

    func body(content: Content) -> some View {
        content
            .frame(
                width: width > 0 ? CGFloat(width) : nil,
                height: height > 0 ? CGFloat(height) : nil
            )
            .background(Color(backgroundColor))
            .scaleEffect(CGFloat(scale))
            .offset(x: CGFloat(offsetX), y: CGFloat(offsetY))
            .opacity(isHidden ? 0 : opacity)
            .allowsHitTesting(!isHidden)
    }
}

@available(iOS 13.0, *)
private func lookinSwiftUIDebugOverrideProperties(
    width: Binding<Double>,
    height: Binding<Double>,
    offsetX: Binding<Double>,
    offsetY: Binding<Double>,
    scale: Binding<Double>,
    isHidden: Binding<Bool>,
    opacity: Binding<Double>,
    backgroundColor: Binding<UIColor>
) -> [LookinSwiftUIProperty] {
    [
        .number(
            section: "SwiftUI Layout Overrides",
            title: "Width (0 = Auto)",
            value: lookinClampedBinding(width, range: 0...10_000)
        ),
        .number(
            section: "SwiftUI Layout Overrides",
            title: "Height (0 = Auto)",
            value: lookinClampedBinding(height, range: 0...10_000)
        ),
        .number(
            section: "SwiftUI Layout Overrides",
            title: "Offset X",
            value: lookinClampedBinding(offsetX, range: -10_000...10_000)
        ),
        .number(
            section: "SwiftUI Layout Overrides",
            title: "Offset Y",
            value: lookinClampedBinding(offsetY, range: -10_000...10_000)
        ),
        .number(
            section: "SwiftUI Layout Overrides",
            title: "Scale",
            value: lookinClampedBinding(scale, range: 0.05...10)
        ),
        .bool(
            section: "SwiftUI Appearance Overrides",
            title: "Hidden",
            value: isHidden
        ),
        .number(
            section: "SwiftUI Appearance Overrides",
            title: "Opacity",
            value: lookinClampedBinding(opacity, range: 0...1)
        ),
        .color(
            section: "SwiftUI Appearance Overrides",
            title: "Background Color",
            value: backgroundColor
        ),
    ]
}

@available(iOS 13.0, *)
private func lookinClampedBinding(
    _ binding: Binding<Double>,
    range: ClosedRange<Double>
) -> Binding<Double> {
    Binding(
        get: { binding.wrappedValue },
        set: { newValue in
            guard newValue.isFinite else { return }
            binding.wrappedValue = min(max(newValue, range.lowerBound), range.upperBound)
        }
    )
}

@available(iOS 13.0, *)
private struct LookinSwiftUIRootProbe: UIViewRepresentable {
    let registry: LookinSwiftUIRegistry
    let title: String
    let includeRuntimeNodes: Bool

    func makeUIView(context: Context) -> LookinSwiftUIRootProbeView {
        LookinSwiftUIRootProbeView(
            registry: registry,
            title: title,
            includeRuntimeNodes: includeRuntimeNodes
        )
    }

    func updateUIView(_ uiView: LookinSwiftUIRootProbeView, context: Context) {
        uiView.registry = registry
        uiView.inspectorTitle = title
        uiView.includeRuntimeNodes = includeRuntimeNodes
    }
}

@available(iOS 13.0, *)
private final class LookinSwiftUIRootProbeView: UIView {
    var registry: LookinSwiftUIRegistry
    var inspectorTitle: String
    var includeRuntimeNodes: Bool

    init(registry: LookinSwiftUIRegistry, title: String, includeRuntimeNodes: Bool) {
        self.registry = registry
        inspectorTitle = title
        self.includeRuntimeNodes = includeRuntimeNodes
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
        let registeredSubviews = registry.rawSubviews(in: window)
        let runtimeSnapshot = includeRuntimeNodes ? lookinRuntimeSnapshot() : nil
        let subviews = Self.merging(
            registeredSubviews: registeredSubviews,
            runtimeSubviews: runtimeSnapshot?.subviews ?? []
        )
        var properties: [[String: Any]] = [
            [
                "section": "SwiftUI",
                "title": "Root Nodes",
                "value": NSNumber(value: registeredSubviews.count),
                "valueType": "number",
            ],
        ]
        if let runtimeSnapshot = runtimeSnapshot {
            properties.append(contentsOf: [
                [
                    "section": "SwiftUI",
                    "title": "Runtime Nodes",
                    "value": NSNumber(value: runtimeSnapshot.visibleNodeCount),
                    "valueType": "number",
                ],
                [
                    "section": "SwiftUI",
                    "title": "Raw Runtime Nodes",
                    "value": NSNumber(value: runtimeSnapshot.rawNodeCount),
                    "valueType": "number",
                ],
            ])
        }
        var semanticRoot: [String: Any] = [
            "title": inspectorTitle,
            "subtitle": "SwiftUI Semantic Hierarchy",
            "semanticKind": "swiftui-root",
            "semanticIdentifier": "lookin.swiftui.root.\(inspectorTitle)",
            "properties": properties,
            "subviews": subviews,
        ]
        semanticRoot["frameInWindow"] = NSValue(cgRect: convert(bounds, to: window))
        return [
            "title": inspectorTitle,
            "subviews": [semanticRoot],
        ]
    }

    private func lookinRuntimeSnapshot() -> LookinSwiftUIViewDebugSnapshot? {
        var ancestor = superview
        while let view = ancestor {
            if let provider = view as? LookinSwiftUIViewDebugDataProviding {
                return provider.lookinSwiftUISnapshot()
            }
            ancestor = view.superview
        }
        return nil
    }

    private static func merging(
        registeredSubviews: [[String: Any]],
        runtimeSubviews: [[String: Any]]
    ) -> [[String: Any]] {
        guard !runtimeSubviews.isEmpty else { return registeredSubviews }
        guard var firstRegistered = registeredSubviews.first else { return runtimeSubviews }

        let existingChildren = firstRegistered["subviews"] as? [[String: Any]] ?? []
        firstRegistered["subviews"] = existingChildren + runtimeSubviews
        return [firstRegistered] + registeredSubviews.dropFirst()
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
        var includesUIKitHierarchy: Bool

        init(
            id: String,
            order: UInt,
            probeView: UIView,
            parentID: String?,
            title: String,
            source: String,
            properties: [LookinSwiftUIProperty],
            includesUIKitHierarchy: Bool
        ) {
            self.id = id
            self.order = order
            self.probeView = probeView
            self.parentID = parentID
            self.title = title
            self.source = source
            self.properties = properties
            self.includesUIKitHierarchy = includesUIKitHierarchy
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
        probeView: UIView,
        includesUIKitHierarchy: Bool = false
    ) {
        if let entry = entries[id] {
            entry.probeView = probeView
            entry.parentID = parentID
            entry.title = title
            entry.source = source
            entry.properties = properties
            entry.includesUIKitHierarchy = includesUIKitHierarchy
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
            properties: properties,
            includesUIKitHierarchy: includesUIKitHierarchy
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

        var frameInWindow: CGRect?
        if let probeView = entry.probeView {
            let frame = probeView.convert(probeView.bounds, to: window)
            frameInWindow = frame
            properties.append(contentsOf: [
                lookinSwiftUIGeometryProperty(title: "X", value: frame.origin.x),
                lookinSwiftUIGeometryProperty(title: "Y", value: frame.origin.y),
                lookinSwiftUIGeometryProperty(title: "Width", value: frame.width),
                lookinSwiftUIGeometryProperty(title: "Height", value: frame.height),
            ])
        }

        var dictionary: [String: Any] = [
            "title": entry.title,
            "subtitle": entry.source,
            "semanticKind": "swiftui-node",
            "semanticIdentifier": entry.id,
            "properties": properties,
        ]

        if let frame = frameInWindow {
            dictionary["frameInWindow"] = NSValue(cgRect: frame)
        }

        var children = (childrenByParentID[entry.id] ?? [])
            .filter { !nextVisited.contains($0.id) }
            .map {
                rawDictionary(
                    for: $0,
                    in: window,
                    childrenByParentID: childrenByParentID,
                    visited: nextVisited
                )
            }
        if entry.includesUIKitHierarchy, let rootView = entry.probeView {
            var remainingNodeCount = 300
            children.append(contentsOf: rootView.subviews.flatMap {
                rawUIKitDictionaries(
                    for: $0,
                    in: window,
                    depth: 0,
                    remainingNodeCount: &remainingNodeCount
                )
            })
        }
        if !children.isEmpty {
            dictionary["subviews"] = children
        }

        return dictionary
    }

    private func rawUIKitDictionaries(
        for view: UIView,
        in window: UIWindow,
        depth: Int,
        remainingNodeCount: inout Int
    ) -> [[String: Any]] {
        guard depth <= 20, remainingNodeCount > 0, view.window === window else { return [] }
        guard !view.isHidden, view.alpha > 0.01 else { return [] }
        remainingNodeCount -= 1

        let childDictionaries = view.subviews.flatMap {
            rawUIKitDictionaries(
                for: $0,
                in: window,
                depth: depth + 1,
                remainingNodeCount: &remainingNodeCount
            )
        }
        let frame = view.convert(view.bounds, to: window).standardized
        guard Self.hasVisibleGeometry(frame, in: window), Self.shouldDisplayUIKitView(view) else {
            return childDictionaries
        }

        let className = NSStringFromClass(type(of: view))
        let shortClassName = className.split(separator: ".").last.map(String.init) ?? className
        var dictionary: [String: Any] = [
            "title": shortClassName,
            "subtitle": className,
            "semanticKind": "swiftui-representable-uikit-node",
            "semanticIdentifier": "lookin.representable.uikit.\(String(describing: ObjectIdentifier(view)))",
            "frameInWindow": NSValue(cgRect: frame),
            "properties": [
                [
                    "section": "UIKit",
                    "title": "Class",
                    "value": className,
                    "valueType": "string",
                ],
                [
                    "section": "UIKit",
                    "title": "Alpha",
                    "value": NSNumber(value: Double(view.alpha)),
                    "valueType": "number",
                ],
                [
                    "section": "UIKit",
                    "title": "User Interaction",
                    "value": NSNumber(value: view.isUserInteractionEnabled),
                    "valueType": "boolean",
                ],
            ],
        ]
        if !childDictionaries.isEmpty {
            dictionary["subviews"] = childDictionaries
        }
        return [dictionary]
    }

    private static func hasVisibleGeometry(_ frame: CGRect, in window: UIWindow) -> Bool {
        guard frame.origin.x.isFinite,
              frame.origin.y.isFinite,
              frame.size.width.isFinite,
              frame.size.height.isFinite,
              frame.width > 0,
              frame.height > 0 else {
            return false
        }
        return frame.intersects(window.bounds)
    }

    private static func shouldDisplayUIKitView(_ view: UIView) -> Bool {
        if view is UIScrollView ||
            view is UICollectionView ||
            view is UICollectionViewCell ||
            view is UIControl ||
            view is UIImageView ||
            view is UILabel ||
            view is UIVisualEffectView {
            return true
        }

        let className = NSStringFromClass(type(of: view))
        guard let separator = className.firstIndex(of: ".") else { return false }
        let moduleName = String(className[..<separator])
        return moduleName != "LookinServerSwift" &&
            moduleName != "SwiftUI" &&
            moduleName != "SwiftUICore" &&
            moduleName != "UIKit" &&
            moduleName != "UIKitCore"
    }

    private func lookinSwiftUIGeometryProperty(
        title: String,
        value: CGFloat
    ) -> [String: Any] {
        [
            "section": "SwiftUI Current Geometry",
            "title": title,
            "value": NSNumber(value: Double(value)),
            "valueType": "number",
        ]
    }
}

@available(iOS 13.0, *)
private struct LookinSwiftUIViewDebugSnapshot {
    let rawNodeCount: Int
    let visibleNodeCount: Int
    let subviews: [[String: Any]]
}

@available(iOS 13.0, *)
@MainActor
private protocol LookinSwiftUIViewDebugDataProviding {
    func lookinSwiftUISnapshot() -> LookinSwiftUIViewDebugSnapshot
}

@available(iOS 13.0, *)
@MainActor
extension _UIHostingView: LookinSwiftUIViewDebugDataProviding {
    fileprivate func lookinSwiftUISnapshot() -> LookinSwiftUIViewDebugSnapshot {
        var remainingNodeCount = 1_200
        let roots = _viewDebugData().flatMap { data in
            LookinSwiftUIViewDebugNode.nodes(
                from: data,
                hostView: self,
                depth: 0,
                remainingNodeCount: &remainingNodeCount
            )
        }
        let subviews = roots.flatMap(\.lookinRepresentations)
        return LookinSwiftUIViewDebugSnapshot(
            rawNodeCount: roots.reduce(0) { $0 + $1.nodeCount },
            visibleNodeCount: LookinSwiftUIViewDebugNode.representationCount(in: subviews),
            subviews: subviews
        )
    }
}

@available(iOS 13.0, *)
private struct LookinSwiftUIViewDebugNode {
    private static let maximumDepth = 48
    private static let frameworkModuleNames: Set<String> = [
        "AttributeGraph",
        "LookinServerSwift",
        "SwiftUI",
        "SwiftUICore",
        "UIKit",
        "_SwiftUI",
    ]
    private static let runtimeContainerNames: Set<String> = [
        "AnyView",
        "Element",
        "Group",
        "ModifiedContent",
        "Optional",
        "PlaceholderContentView",
        "Tree",
        "TupleView",
        "UpdateBridgesToAllowedBehaviors",
        "_ConditionalContent",
        "_ViewList_View",
        "_ViewModifier_Content",
    ]
    private static let meaningfulRuntimeNames: Set<String> = [
        "AsyncImage",
        "Button",
        "Canvas",
        "Color",
        "ContentUnavailableView",
        "ControlGroup",
        "DatePicker",
        "DisclosureGroup",
        "Divider",
        "ForEach",
        "Form",
        "GeometryReader",
        "Grid",
        "GridRow",
        "GroupBox",
        "HStack",
        "Image",
        "Label",
        "LabeledContent",
        "LazyHGrid",
        "LazyHStack",
        "LazyVGrid",
        "LazyVStack",
        "Link",
        "List",
        "Map",
        "NavigationSplitView",
        "NavigationStack",
        "Picker",
        "ProgressView",
        "ScrollView",
        "Section",
        "SecureField",
        "ShapeView",
        "Slider",
        "Spacer",
        "Stepper",
        "TabView",
        "Text",
        "TextEditor",
        "TextField",
        "TimelineView",
        "Toggle",
        "VStack",
        "VideoPlayer",
        "ZStack",
        "_GridLayout",
        "_HStackLayout",
        "_VStackLayout",
        "_ZStackLayout",
    ]

    let type: String
    let position: CGPoint?
    let size: CGSize?
    let transform: String?
    let children: [LookinSwiftUIViewDebugNode]
    let hostView: UIView

    var nodeCount: Int {
        1 + children.reduce(0) { $0 + $1.nodeCount }
    }

    static func nodes(
        from rawData: Any,
        hostView: UIView,
        depth: Int,
        remainingNodeCount: inout Int
    ) -> [LookinSwiftUIViewDebugNode] {
        guard depth <= maximumDepth, remainingNodeCount > 0 else { return [] }
        remainingNodeCount -= 1

        var properties: [String: String] = [:]
        var rawChildren: [Any] = []
        for child in Mirror(reflecting: rawData).children {
            switch child.label {
            case "data":
                properties = reflectedProperties(from: child.value)
            case "childData":
                rawChildren = Mirror(reflecting: child.value).children.map(\.value)
            default:
                continue
            }
        }

        let children = rawChildren.flatMap {
            nodes(
                from: $0,
                hostView: hostView,
                depth: depth + 1,
                remainingNodeCount: &remainingNodeCount
            )
        }
        guard let type = properties["type"], !type.isEmpty else { return children }

        return [LookinSwiftUIViewDebugNode(
            type: type,
            position: parsePoint(properties["position"]),
            size: parseSize(properties["size"]),
            transform: properties["transform"],
            children: children,
            hostView: hostView
        )]
    }

    private static func reflectedProperties(from rawProperties: Any) -> [String: String] {
        var result: [String: String] = [:]
        for entry in Mirror(reflecting: rawProperties).children {
            let pair = Array(Mirror(reflecting: entry.value).children)
            guard pair.count == 2 else { continue }
            let key = String(describing: pair[0].value)
            guard key == "type" || key == "position" || key == "size" || key == "transform" else {
                continue
            }
            result[key] = String(describing: pair[1].value)
        }
        return result
    }

    private static func parsePoint(_ value: String?) -> CGPoint? {
        guard let tuple = parseTuple(value) else { return nil }
        return CGPoint(x: tuple.0, y: tuple.1)
    }

    private static func parseSize(_ value: String?) -> CGSize? {
        guard let tuple = parseTuple(value), tuple.0 >= 0, tuple.1 >= 0 else { return nil }
        return CGSize(width: tuple.0, height: tuple.1)
    }

    private static func parseTuple(_ value: String?) -> (CGFloat, CGFloat)? {
        guard let value = value?.trimmingCharacters(in: .whitespacesAndNewlines),
              value.first == "(", value.last == ")" else { return nil }
        let components = value.dropFirst().dropLast().split(separator: ",", maxSplits: 1)
        guard components.count == 2,
              let first = Double(components[0].trimmingCharacters(in: .whitespaces)),
              let second = Double(components[1].trimmingCharacters(in: .whitespaces)),
              first.isFinite, second.isFinite else { return nil }
        return (CGFloat(first), CGFloat(second))
    }

    var lookinRepresentations: [[String: Any]] {
        let childRepresentations = children.flatMap(\.lookinRepresentations)
        if !shouldDisplayRuntimeNode {
            return childRepresentations
        }

        var representation: [String: Any] = [
            "title": displayTitle,
            "semanticKind": "swiftui-runtime-node",
            "properties": lookinProperties,
        ]
        if let size = size {
            representation["subtitle"] = "\(format(size.width)) × \(format(size.height))"
        }
        if let frame = frameInWindow {
            representation["frameInWindow"] = NSValue(cgRect: frame)
        }
        if !childRepresentations.isEmpty {
            representation["subviews"] = childRepresentations
        }
        return [representation]
    }

    static func representationCount(in representations: [[String: Any]]) -> Int {
        representations.reduce(0) { count, representation in
            let children = representation["subviews"] as? [[String: Any]] ?? []
            return count + 1 + representationCount(in: children)
        }
    }

    private var shouldDisplayRuntimeNode: Bool {
        if !Self.sourceViewNames(in: type).isEmpty {
            return true
        }
        if Self.meaningfulRuntimeNames.contains(shortTypeName) {
            return true
        }
        if Self.runtimeContainerNames.contains(shortTypeName) || shortTypeName.hasSuffix("Modifier") {
            return false
        }
        if shortTypeName.hasPrefix("_") {
            return false
        }

        return children.isEmpty && frameInWindow != nil
    }

    private var shortTypeName: String {
        let base = type.split(separator: "<", maxSplits: 1).first.map(String.init) ?? type
        return base.split(separator: ".").last.map(String.init) ?? base
    }

    private var displayTitle: String {
        Self.sourceViewNames(in: type).last ?? shortTypeName
    }

    private static func sourceViewNames(in type: String) -> [String] {
        var names: [String] = []
        var start = type.startIndex
        while let separator = type[start...].firstIndex(of: ".") {
            let moduleStart = type[..<separator].lastIndex {
                !($0.isLetter || $0.isNumber || $0 == "_")
            }.map { type.index(after: $0) } ?? type.startIndex
            let moduleName = String(type[moduleStart..<separator])
            let nameStart = type.index(after: separator)
            let nameEnd = type[nameStart...].firstIndex {
                !($0.isLetter || $0.isNumber || $0 == "_")
            } ?? type.endIndex
            let name = String(type[nameStart..<nameEnd])
            if !frameworkModuleNames.contains(moduleName),
               name.hasSuffix("View"),
               !names.contains(name) {
                names.append(name)
            }
            guard nameEnd < type.endIndex else { break }
            start = type.index(after: nameEnd)
        }
        return names
    }

    private var frameInWindow: CGRect? {
        guard let position = position, let size = size, size.width > 0, size.height > 0 else {
            return nil
        }
        let frame = CGRect(
            x: position.x - size.width / 2,
            y: position.y - size.height / 2,
            width: size.width,
            height: size.height
        )
        return hostView.convert(frame, to: nil)
    }

    private var lookinProperties: [[String: Any]] {
        var result = [property(title: "Type", value: type)]
        if let position = position {
            result.append(property(title: "Position", value: "(\(format(position.x)), \(format(position.y)))"))
        }
        if let size = size {
            result.append(property(title: "Size", value: "(\(format(size.width)), \(format(size.height)))"))
        }
        if let transform = transform, !transform.isEmpty {
            result.append(property(title: "Transform", value: transform))
        }
        return result
    }

    private func property(title: String, value: String) -> [String: Any] {
        ["section": "SwiftUI", "title": title, "value": value, "valueType": "string"]
    }

    private func format(_ value: CGFloat) -> String {
        String(format: "%.2f", Double(value))
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
