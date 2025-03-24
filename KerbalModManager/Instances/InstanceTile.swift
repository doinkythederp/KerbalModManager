//
//  InstanceTile.swift
//  KerbalModManager
//
//  Created by Lewis McClelland on 3/4/25.
//

import CkanAPI
import SwiftUI

struct InstanceTile: View {
    var instance: GameInstance
    var isSelected: Bool
    @Binding var allowKeyboardNavigation: Bool

    @State private var isHovering = false
    @State private var isRenaming = false
    @FocusState private var renameFocused: Bool
    @State private var editedName = ""

    @Environment(\.isFocused) private var isFocused
    @Environment(Store.self) private var store: Store?

    private var strokeStyle: AnyShapeStyle {
        isSelected
            ? AnyShapeStyle(.selection)
            : AnyShapeStyle(.clear)
    }

    @ViewBuilder
    var label: some View {
        HStack(spacing: 0) {
            Button("Edit", systemImage: "pencil.line") {
                if isRenaming {
                    finishRenaming()
                } else {
                    rename()
                }
            }
            .buttonStyle(.borderless)
            .opacity(isHovering || isRenaming ? 1 : 0)
            .frame(width: 14)
            .help("Rename the game instance")

            ZStack {
                if isRenaming {
                    TextField("Name", text: $editedName, axis: .vertical)
                        .textFieldStyle(.plain)
                        .labelsHidden()
                        .onSubmit { finishRenaming() }
                        .onAppear { editedName = instance.name }
                        .onChange(of: instance.name) {
                            editedName = instance.name
                        }
                        .onKeyPress(.escape) {
                            if isRenaming {
                                cancelRenaming()
                                return .handled
                            }

                            return .ignored
                        }
                        .focused($renameFocused)
                        .defaultFocus($renameFocused, true)
                } else {
                    Text(isRenaming ? editedName : instance.name)
                }
            }
            .lineLimit(2)
            .font(.headline)
            .padding(4)
            .foregroundStyle(isSelected && isFocused ? .white : .primary)
            .background(strokeStyle)
            .background(.quaternary)
            .clipShape(.rect(cornerRadius: 8))
            .padding(.horizontal, 4)
            .onChange(of: isRenaming) {
                // When renaming, arrow keys should control text caret, not navigation.
                allowKeyboardNavigation = !isRenaming
                renameFocused = isRenaming
                if !isRenaming {
                    store?.instanceBeingRenamed = nil
                }
            }

            Color.clear.frame(width: 14) // offset the button to keep text centered
        }
        .labelStyle(.iconOnly)
        .frame(maxWidth: .infinity)
        .onHover {
            isHovering = $0
        }
        .onChange(of: store?.instanceBeingRenamed?.id) {
            if store?.instanceBeingRenamed == instance {
                // Some other view wants us to be renamed!
                isRenaming = true
            }
        }
    }

    @ViewBuilder
    var contextMenu: some View {
        Group {
            Button("Rename", systemImage: "pencil") {
                rename()
            }
            Divider()
            ControlGroup("Local Files") {
                Button("Reveal in Finder", systemImage: "folder") {
                    instance.openInFinder()
                }
                Button("Copy Path", systemImage: "clipboard") {
                    instance.copyDirectory()
                }
                Text(instance.directory.string)
                    .textSelection(.enabled)
            }
        }
        .labelStyle(.titleAndIcon)
    }

    @ViewBuilder
    var optionsOverlay: some View {
        Menu("Options", systemImage: "gearshape") {
            contextMenu
        }
        .menuStyle(.button)
        .labelStyle(.iconOnly)
        .background(.ultraThickMaterial)
        .clipShape(.rect(cornerRadius: 7))
        .padding(5)
        .fixedSize()
        .disabled(!isSelected)
    }

    var body: some View {
        VStack {
            Image(ImageResource.CoverArt.kerbalSpaceProgram)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: Self.size)
                .clipShape(.containerRelative)
                .overlay(alignment: .topTrailing) {
                    optionsOverlay
                }
                .overlay {
                    ContainerRelativeShape()
                        .inset(by: -Self.selectionStrokeWidth / 2)
                        .stroke(
                            strokeStyle, lineWidth: Self.selectionStrokeWidth)
                }
                .containerShape(.rect(cornerRadius: 10))
                .shadow(radius: 6)
                .padding(2)

            label.fixedSize(horizontal: false, vertical: true)
        }
        .frame(width: Self.size)
        .contextMenu { contextMenu }

    }

    func rename() {
        editedName = instance.name
        isRenaming = true
    }

    func cancelRenaming() {
        editedName = instance.name
        isRenaming = false
    }

    func finishRenaming() {
        instance.rename(editedName)
        isRenaming = false
    }
}

extension InstanceTile {
    nonisolated static let size: CGFloat = 200
    nonisolated static let selectionStrokeWidth: CGFloat = 3
}

#Preview {
    @Previewable @State var instance = GameInstance(
        name: "Kerbal Space Program",
        directory: "/Applications/Kerbal Space Program")
    @Previewable @FocusState var focus: Bool

    HStack(spacing: 30) {
        InstanceTile(
            instance: instance,
            isSelected: true,
            allowKeyboardNavigation: .constant(true)
        )
        InstanceTile(
            instance: instance,
            isSelected: false,
            allowKeyboardNavigation: .constant(true)
        )
    }
    .padding()
    .focusable()
    .defaultFocus($focus, true)
    .focusEffectDisabled()
}
