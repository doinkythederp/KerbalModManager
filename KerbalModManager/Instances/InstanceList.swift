//
//  InstanceList.swift
//  KerbalModManager
//
//  Created by Lewis McClelland on 3/4/25.
//

import CkanAPI
import SwiftUI
import System

struct SelectedGameInstance: FocusedValueKey {
    typealias Value = Binding<GameInstance?>
}

extension FocusedValues {
    var selectedGameInstance: Binding<GameInstance?>? {
        get { self[SelectedGameInstance.self] }
        set { self[SelectedGameInstance.self] = newValue }
    }
}

private let columns: [GridItem] = [
    .init(.adaptive(minimum: 200), spacing: 0)
]

struct InstanceList: View {
    @Binding var instances: [GameInstance]
    @State private var selection: GameInstance?
    @State private var allowKeyboardNavigation = true

    @Environment(\.layoutDirection) private var layoutDirection
    @Environment(NavigationModel.self) private var navigationModel

    var body: some View {
        container { geometryProxy, scrollViewProxy in
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
                            navigate(to: instance)
                        }
                    )
                }
            }
            .padding(Self.spacing)
            .focusable()
            .focusEffectDisabled()
            .focusedValue(\.selectedGameInstance, $selection)
            .onKeyPress(.return, action: {
                if allowKeyboardNavigation, let selection {
                    navigate(to: selection)
                    return .handled
                } else {
                    return .ignored
                }
            })
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

    private func navigate(to instance: GameInstance) {
        navigationModel.selectedInstanceName = instance.name
    }

    // MARK: Grid layout

    private static let spacing: CGFloat = 10

    private var columns: [GridItem] {
        [GridItem(.adaptive(minimum: InstanceTile.size), spacing: 0)]
    }
}

#Preview {
    @Previewable @State var instances = [
        GameInstance(
            name: "Global Kerbal Space Program", directory: "/Applications/Kerbal Space Program"),
        GameInstance(
            name: "Steam KSP",
            directory: FilePath("/Users/\(NSUserName())/Library/Application Support/Steam/SteamApps/common/Kerbal Space Program")
        ),
    ]
    @Previewable @State var navigationModel = NavigationModel()

    if let selection = navigationModel.selectedInstanceName {
        Text(selection)
        Button("Back") {
            navigationModel.selectedInstanceName = nil
        }
    } else {
        InstanceList(instances: $instances)
            .frame(minWidth: 500)
            .environment(navigationModel)
    }

}
