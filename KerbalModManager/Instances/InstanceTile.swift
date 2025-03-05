//
//  InstanceTile.swift
//  KerbalModManager
//
//  Created by Lewis McClelland on 3/4/25.
//

import SwiftUI
import CkanAPI

struct InstanceTile: View {
    @Binding var instance: GameInstance
    var isSelected: Bool
    @Binding var allowKeyboardNavigation: Bool

    @State private var isHovering = false
    @FocusState private var isRenaming: Bool
    @State private var editedName = ""

    @Environment(\.isFocused) private var isFocused

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
                .frame(width: 25)
                .help("Rename the game instance")

            ZStack(alignment: .center) {
                // When editing, the non-editable version of the text mirrors the text field contents
                // in order to help prevent content layout shift when beginning to edit.

                Text(isRenaming ? editedName : instance.name)
                    .opacity(isRenaming ? 0 : 1)

                // Only shows when renaming
                TextField("Name", text: $editedName, axis: .vertical)
                    .onSubmit {
                        finishRenaming()
                    }
                    .onAppear {
                        editedName = instance.name
                    }
                    .onChange(of: instance.name) {
                        editedName = instance.name
                    }
                    .onChange(of: isRenaming) {
                        allowKeyboardNavigation = !isRenaming
                    }
                    .textFieldStyle(.plain)
                    .labelsHidden()
                    .focused($isRenaming)
                    .opacity(isRenaming ? 1 : 0)
            }
            .font(.headline)
            .padding(4)
            .foregroundStyle(isSelected && isFocused ? .white : .primary)
            .background(strokeStyle)
            .background(.quaternary)
            .clipShape(.rect(cornerRadius: 8))

            Color.clear.frame(width: 25)
        }
        .labelStyle(.iconOnly)
        .frame(maxWidth: .infinity)
        .onHover {
            isHovering = $0
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
                    openInFinder()
                }
                Button("Copy Path", systemImage: "clipboard") {
                    copyDirectory()
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
        .tint(isSelected ? .accentColor : .gray)
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
                        .stroke(strokeStyle, lineWidth: Self.selectionStrokeWidth)
                }
                .containerShape(.rect(cornerRadius: 10))
                .shadow(radius: 6)
                .padding(2)


            label.fixedSize()
        }
        .frame(width: Self.size)
        .contextMenu { contextMenu }

    }

    func rename() {
        editedName = instance.name
        isRenaming = true
    }

    func finishRenaming() {
        instance.name = editedName
        isRenaming = false
    }

    func copyDirectory() {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(instance.directory.string, forType: .string)
        pasteboard.setString(instance.fileURL.absoluteString, forType: .fileURL)
    }

    func openInFinder() {
        NSWorkspace.shared.activateFileViewerSelecting([instance.fileURL])
    }
}

extension InstanceTile {
    static let size: CGFloat = 200
    static let selectionStrokeWidth: CGFloat = 3
}


#Preview {
    @Previewable @State var instance = GameInstance(
        name: "Kerbal Space Program",
        directory: "/Applications/Kerbal Space Program")
    @Previewable @FocusState var focus: Bool

    HStack(spacing: 30) {
        InstanceTile(
            instance: $instance,
            isSelected: true,
            allowKeyboardNavigation: .constant(true)
        )
        InstanceTile(
            instance: $instance,
            isSelected: false,
            allowKeyboardNavigation: .constant(true)
        )
    }
    .padding()
    .focusable()
    .defaultFocus($focus, true)
    .focusEffectDisabled()
}
