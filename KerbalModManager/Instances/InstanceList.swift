//
//  InstanceList.swift
//  KerbalModManager
//
//  Created by Lewis McClelland on 3/4/25.
//

import CkanAPI
import SwiftUI
import System
import SFSafeSymbols

struct SelectedGameInstance: FocusedValueKey {
    typealias Value = Binding<GameInstance?>
}

extension FocusedValues {
    var selectedGameInstance: Binding<GameInstance?>? {
        get { self[SelectedGameInstance.self] }
        set { self[SelectedGameInstance.self] = newValue }
    }
}

struct InstanceList: View {
    @Binding var instances: [GameInstance]
    var navigate: (GameInstance) -> Void
    var cancel: () -> Void

    init(
        instances: Binding<[GameInstance]>,
        onNavigate: @escaping (GameInstance) -> Void = { _ in },
        onCancel: @escaping () -> Void = {}
    ) {
        self._instances = instances
        self.navigate = onNavigate
        self.cancel = onCancel
    }

    @State private var selection: GameInstance?
    @State private var allowKeyboardNavigation = true

    @Environment(\.layoutDirection) private var layoutDirection
    @Environment(\.refresh) private var refresh

    var body: some View {
        container { geometryProxy, scrollViewProxy in
            HStack {
                Text("Choose an Instance")
                Spacer()
            }
            .font(.system(size: 35).bold())
            .padding(.horizontal)
            .padding(.top)

            LazyVGrid(columns: columns) {
                ForEach($instances) { $instance in
                    InstanceTile(
                        instance: $instance,
                        isSelected: instance == selection,
                        allowKeyboardNavigation: $allowKeyboardNavigation
                    )
                    .id(instance)
                    .padding(Self.spacing)
                    .onTapGesture { selection = instance }
                    .simultaneousGesture(
                        TapGesture(count: 2).onEnded {
                            navigate(instance)
                        }
                    )
                }
            }
            .padding(.horizontal, Self.spacing)
            .focusable()
            .focusEffectDisabled()
            .focusedValue(\.selectedGameInstance, $selection)
            .onKeyPress(.escape) {
                guard allowKeyboardNavigation else {
                    return .ignored
                }

                selection = nil
                return .handled
            }
            .onMoveCommand { direction in
                selectInstance(
                    in: direction, layoutDirection: layoutDirection,
                    geometryProxy: geometryProxy,
                    scrollViewProxy: scrollViewProxy)
            }
            .onKeyPress(characters: .alphanumerics, phases: .down) { keyPress in
                guard allowKeyboardNavigation else {
                    return .ignored
                }
                return selectInstance(
                    matching: keyPress.characters,
                    scrollViewProxy: scrollViewProxy)
            }
            .onAppear {
                if selection == nil {
                    selection = instances.first
                }
            }
        }
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: 0) {
                Divider()
                HStack {
                    Button("Refresh", systemSymbol: .arrowClockwise) {
                        Task {
                            await refresh?()
                        }
                    }
                    Spacer()
                    Button("Cancel") {
                        cancel()
                    }
                    Button {
                        if let selection {
                            navigate(selection)
                        }
                    } label: {
                        Text("Select").frame(minWidth: 60)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(selection == nil)
                    .keyboardShortcut(.defaultAction)
                }
                .padding(.horizontal)
                .padding(.vertical, 12)
            }
            .background()
        }
        .navigationBarBackButtonHidden()
    }

    // Selection logic based on:
    // https://developer.apple.com/documentation/swiftui/focus-cookbook-sample

    private func container<Content: View>(
        @ViewBuilder content: @escaping (
            _ geometryProxy: GeometryProxy,
            _ scrollViewProxy: ScrollViewProxy
        ) -> Content
    ) -> some View {
        GeometryReader { geometryProxy in
            ScrollViewReader { scrollViewProxy in
                ScrollView {
                    content(geometryProxy, scrollViewProxy)
                }
            }
        }
    }

    private func selectInstance(
        in direction: MoveCommandDirection,
        layoutDirection: LayoutDirection,
        geometryProxy: GeometryProxy,
        scrollViewProxy: ScrollViewProxy
    ) {
        let direction = direction.transform(from: layoutDirection)
        let rowWidth = geometryProxy.size.width - Self.spacing * 2
        let instancesPerRow = Int(floor(rowWidth / InstanceTile.size))

        var newIndex: Int
        if let selection, let currentIndex = instances.firstIndex(of: selection)
        {
            switch direction {
            case .left:
                if currentIndex % instancesPerRow == 0 { return }
                newIndex = currentIndex - 1
            case .right:
                if currentIndex % instancesPerRow == instancesPerRow - 1 {
                    return
                }
                newIndex = currentIndex + 1
            case .up:
                newIndex = currentIndex - instancesPerRow
            case .down:
                newIndex = currentIndex + instancesPerRow
            @unknown default:
                return
            }
        } else {
            newIndex = 0
        }

        if newIndex >= 0 && newIndex < instances.count {
            selection = instances[newIndex]
            scrollViewProxy.scrollTo(selection)
        }
    }

    private func selectInstance(
        matching characters: String,
        scrollViewProxy: ScrollViewProxy
    ) -> KeyPress.Result {
        if let matchedInstance = instances.first(where: { instance in
            instance.name.lowercased().starts(with: characters)
        }) {
            selection = matchedInstance
            scrollViewProxy.scrollTo(matchedInstance)
            return .handled
        }
        return .ignored
    }

    // MARK: Grid layout

    nonisolated static let spacing: CGFloat = 20

    private let columns: [GridItem] = [
        .init(.adaptive(minimum: InstanceTile.size), spacing: InstanceList.spacing)
    ]
}

#Preview {
    @Previewable @State var instances = [
        GameInstance(
            name: "Global Kerbal Space Program",
            directory: "/Applications/Kerbal Space Program"),
        GameInstance(
            name: "Steam KSP",
            directory: FilePath(
                "/Users/\(NSUserName())/Library/Application Support/Steam/SteamApps/common/Kerbal Space Program"
            )
        ),
    ]
    @Previewable @State var selection: GameInstance?

    if let instance = selection {
        Text(instance.name)
        Button("Back") {
            selection = nil
        }
    } else {
        InstanceList(instances: $instances) {
            selection = $0
        }
            .frame(minWidth: 500)
    }

}

