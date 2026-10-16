import SwiftUI

#if os(macOS)
import AppKit
#else
import UIKit
#endif

struct ContentView: View {
    @State private var library = ShaderLibraryModel()
    @State private var selectedIndex = 0
    @State private var touchPoint = UnitPoint(x: 0.5, y: 0.5)
    @State private var copied = false

    private var selectedShader: ShaderDefinition? {
        library.shaders.indices.contains(selectedIndex) ? library.shaders[selectedIndex] : nil
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            GeometryReader { geometry in
                VStack(spacing: 0) {
                    header
                    Divider().overlay(.white.opacity(0.08))

                    if geometry.size.width < 700 {
                        compactShaderPicker
                        Divider().overlay(.white.opacity(0.08))
                        inspector
                    } else {
                        HStack(spacing: 0) {
                            shaderList
                            Divider().overlay(.white.opacity(0.08))
                            inspector
                        }
                    }
                }
                .foregroundStyle(.white)
            }
        }
        .preferredColorScheme(.dark)
        .task {
            library.load()
        }
        .onChange(of: selectedIndex) {
            guard let selectedShader else { return }
            library.values = selectedShader.params.map(\.defaultValue)
            touchPoint = UnitPoint(x: 0.5, y: 0.5)
        }
    }

    private var header: some View {
        HStack(spacing: 12) {
            Image(systemName: "wand.and.stars")
                .font(.title3.weight(.semibold))
                .foregroundStyle(.mint)

            VStack(alignment: .leading, spacing: 2) {
                Text("Shader Lab")
                    .font(.headline)
                Text("SwiftUIShaders · \(library.shaders.count) effects")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button("Reset", systemImage: "arrow.counterclockwise") {
                guard let selectedShader else { return }
                library.values = selectedShader.params.map(\.defaultValue)
                touchPoint = UnitPoint(x: 0.5, y: 0.5)
            }
            .labelStyle(.titleAndIcon)
            .buttonStyle(.bordered)
            .tint(.white.opacity(0.7))
            .accessibilityLabel("Reset shader parameters")
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
    }

    private var shaderList: some View {
        List {
            Section("Effects") {
                ForEach(Array(library.shaders.enumerated()), id: \.offset) { index, shader in
                    Button {
                        selectedIndex = index
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: shader.animated ? "sparkles" : "circle.dotted")
                                .foregroundStyle(index == selectedIndex ? .mint : .secondary)
                                .frame(width: 18)
                            Text(shader.title)
                                .font(.subheadline)
                            Spacer()
                            if index == selectedIndex {
                                Image(systemName: "checkmark")
                                    .font(.caption.weight(.bold))
                                    .foregroundStyle(.mint)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Select \(shader.title) shader")
                    .listRowBackground(index == selectedIndex ? Color.white.opacity(0.08) : .clear)
                }
            }
        }
        .listStyle(.sidebar)
        .scrollContentBackground(.hidden)
        .frame(minWidth: 190, idealWidth: 220, maxWidth: 260)
    }

    private var compactShaderPicker: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 8) {
                ForEach(Array(library.shaders.enumerated()), id: \.offset) { index, shader in
                    Button {
                        selectedIndex = index
                    } label: {
                        Label(shader.title, systemImage: shader.animated ? "sparkles" : "circle.dotted")
                            .lineLimit(1)
                    }
                    .buttonStyle(.bordered)
                    .tint(index == selectedIndex ? .mint : .white.opacity(0.75))
                    .accessibilityLabel("Select \(shader.title) shader")
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
        }
        .scrollIndicators(.hidden)
    }

    @ViewBuilder
    private var inspector: some View {
        if let selectedShader {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    preview(shader: selectedShader)
                    parameterControls(shader: selectedShader)
                    modifierCall(shader: selectedShader)
                }
                .padding(20)
                .frame(maxWidth: 760, alignment: .leading)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            ContentUnavailableView("Loading shaders", systemImage: "hourglass")
        }
    }

    @ViewBuilder
    private func preview(shader: ShaderDefinition) -> some View {
        if shader.animated {
            TimelineView(.animation) { context in
                previewContent(
                    shader: shader,
                    time: Float(context.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 3600))
                )
            }
        } else {
            previewContent(shader: shader, time: 0)
        }
    }

    private func previewContent(shader: ShaderDefinition, time: Float) -> some View {
        GeometryReader { proxy in
            Image("ShaderWallpaper")
                .resizable()
                .scaledToFill()
                .frame(maxWidth: .infinity, minHeight: 300, maxHeight: 520)
                .clipped()
                .layerEffect(
                    library.shader(for: shader, size: proxy.size, time: time, touchPoint: touchPoint),
                    maxSampleOffset: CGSize(width: 64, height: 64)
                )
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                .overlay(alignment: .topLeading) {
                    Label(shader.animated ? "LIVE" : "STATIC", systemImage: shader.animated ? "circle.fill" : "circle")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(shader.animated ? .mint : .white.opacity(0.8))
                        .padding(10)
                }
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            touchPoint = UnitPoint(
                                x: min(max(value.location.x / max(proxy.size.width, 1), 0), 1),
                                y: min(max(value.location.y / max(proxy.size.height, 1), 0), 1)
                            )
                        }
                )
                .accessibilityLabel("Shader preview for \(shader.title)")
                .accessibilityHint("Drag across the preview to move the touch point")
        }
        .frame(height: 360)
    }

    private func parameterControls(shader: ShaderDefinition) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(shader.title)
                    .font(.title2.weight(.semibold))
                Spacer()
                Text(shader.metal)
                    .font(.caption.monospaced())
                    .foregroundStyle(.secondary)
            }

            ForEach(Array(shader.params.enumerated()), id: \.offset) { index, parameter in
                if parameter.type == .point {
                    HStack {
                        Label(parameter.label, systemImage: "hand.point.up.left")
                        Spacer()
                        Text("Drag preview")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                } else {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text(parameter.label)
                            Spacer()
                            Text(value(for: index, parameter: parameter))
                                .font(.caption.monospaced())
                                .foregroundStyle(.secondary)
                        }
                        Slider(
                            value: Binding(
                                get: { library.values.indices.contains(index) ? library.values[index] : parameter.defaultValue },
                                set: { library.values[index] = $0 }
                            ),
                            in: parameter.min...parameter.max
                        )
                        .tint(.mint)
                        .accessibilityLabel(parameter.label)
                        .accessibilityValue(value(for: index, parameter: parameter))
                    }
                }
            }
        }
    }

    private func modifierCall(shader: ShaderDefinition) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Modifier call")
                    .font(.headline)
                Spacer()
                Button(copied ? "Copied" : "Copy", systemImage: copied ? "checkmark" : "doc.on.doc") {
                    let call = library.modifierCall(for: shader, values: library.values, touchPoint: touchPoint)
                    #if os(macOS)
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(call, forType: .string)
                    #else
                    UIPasteboard.general.string = call
                    #endif
                    copied = true
                }
                .labelStyle(.titleAndIcon)
                .buttonStyle(.bordered)
                .accessibilityLabel("Copy modifier call")
            }

            Text(library.modifierCall(for: shader, values: library.values, touchPoint: touchPoint))
                .font(.caption.monospaced())
                .foregroundStyle(.mint.opacity(0.9))
                .textSelection(.enabled)
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
    }

    private func value(for index: Int, parameter: ShaderParameter) -> String {
        let value = library.values.indices.contains(index) ? library.values[index] : parameter.defaultValue
        return String(format: "%.2f", value)
    }
}

#Preview {
    ContentView()
}
