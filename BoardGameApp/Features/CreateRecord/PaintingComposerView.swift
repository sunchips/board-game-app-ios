import SwiftUI

struct PaintingComposerView: View {
    let paintingNumber: Int
    @Binding var integers: [String: Int]
    @Binding var booleans: [String: Bool]

    enum SwatchColor: String, CaseIterable, Identifiable {
        case red, yellow, green, blue, purple
        var id: String { rawValue }

        var displayColor: Color {
            switch self {
            case .red: .red
            case .yellow: .yellow
            case .green: .green
            case .blue: .blue
            case .purple: .purple
            }
        }
    }

    enum Element: String, CaseIterable, Identifiable {
        case hue, shape, texture, tone
        var id: String { rawValue }
        var label: String { rawValue.capitalized }
        var icon: String {
            switch self {
            case .hue: "paintpalette"
            case .shape: "pentagon"
            case .texture: "circle.grid.cross"
            case .tone: "circle.lefthalf.filled"
            }
        }
    }

    enum SilverBonus: String, CaseIterable, Identifiable {
        case hue, shape, texture, tone
        var id: String { rawValue }
        var label: String { "Silver/\(rawValue.capitalized)" }
        var element: Element {
            switch self {
            case .hue: .hue
            case .shape: .shape
            case .texture: .texture
            case .tone: .tone
            }
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            ForEach(SwatchColor.allCases) { color in
                swatchRow(color: color)
                if color != .purple {
                    Divider()
                }
            }
        }
        .padding(.vertical, 4)

        elementSummary
            .onAppear { syncComputedFields() }
    }

    @ViewBuilder
    private func swatchRow(color: SwatchColor) -> some View {
        HStack(spacing: 8) {
            Circle()
                .fill(color.displayColor)
                .frame(width: 20, height: 20)

            Picker("", selection: elementBinding(swatchKey(color, slot: 1))) {
                Text("—").tag("")
                ForEach(Element.allCases) { e in
                    Label(e.label, systemImage: e.icon).tag(e.rawValue)
                }
            }
            .labelsHidden()
            .frame(maxWidth: .infinity)

            Picker("", selection: elementBinding(swatchKey(color, slot: 2))) {
                Text("—").tag("")
                ForEach(Element.allCases) { e in
                    Label(e.label, systemImage: e.icon).tag(e.rawValue)
                }
            }
            .labelsHidden()
            .frame(maxWidth: .infinity)

            silverBonusMenu(color: color)
        }
        .padding(.vertical, 4)
    }

    @ViewBuilder
    private func silverBonusMenu(color: SwatchColor) -> some View {
        let activeCount = SilverBonus.allCases.filter { bonus in
            booleans[silverKey(color, bonus: bonus)] == true
        }.count

        Menu {
            ForEach(SilverBonus.allCases) { bonus in
                Toggle(bonus.label, isOn: silverBinding(color: color, bonus: bonus))
            }
        } label: {
            HStack(spacing: 2) {
                Image(systemName: "star.fill")
                    .foregroundStyle(.gray)
                    .font(.caption)
                if activeCount > 0 {
                    Text("\(activeCount)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(width: 36)
        }
    }

    private var elementSummary: some View {
        HStack {
            ForEach(Element.allCases) { element in
                Label("\(computeElementCount(element))", systemImage: element.icon)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Label("\(computeSilverRibbons())", systemImage: "star.fill")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Keys

    private func swatchKey(_ color: SwatchColor, slot: Int) -> String {
        "composer_\(paintingNumber)_\(color.rawValue)_e\(slot)"
    }

    private func silverKey(_ color: SwatchColor, bonus: SilverBonus) -> String {
        "composer_\(paintingNumber)_\(color.rawValue)_silver_\(bonus.rawValue)"
    }

    // MARK: - Bindings

    private func elementBinding(_ key: String) -> Binding<String> {
        Binding(
            get: {
                switch integers[key] {
                case 1: Element.hue.rawValue
                case 2: Element.shape.rawValue
                case 3: Element.texture.rawValue
                case 4: Element.tone.rawValue
                default: ""
                }
            },
            set: { newValue in
                let encoded: Int
                switch newValue {
                case Element.hue.rawValue: encoded = 1
                case Element.shape.rawValue: encoded = 2
                case Element.texture.rawValue: encoded = 3
                case Element.tone.rawValue: encoded = 4
                default: encoded = 0
                }
                integers[key] = encoded
                syncComputedFields()
            }
        )
    }

    private func silverBinding(color: SwatchColor, bonus: SilverBonus) -> Binding<Bool> {
        let key = silverKey(color, bonus: bonus)
        return Binding(
            get: { booleans[key] ?? false },
            set: { newValue in
                booleans[key] = newValue
                syncComputedFields()
            }
        )
    }

    // MARK: - Computation

    private func computeElementCount(_ element: Element) -> Int {
        var count = 0
        for color in SwatchColor.allCases {
            for slot in 1...2 {
                let stored = integers[swatchKey(color, slot: slot)] ?? 0
                let mapped: String = switch stored {
                case 1: Element.hue.rawValue
                case 2: Element.shape.rawValue
                case 3: Element.texture.rawValue
                case 4: Element.tone.rawValue
                default: ""
                }
                if mapped == element.rawValue { count += 1 }
            }
        }
        return count
    }

    private func computeSilverRibbons() -> Int {
        var total = 0
        for color in SwatchColor.allCases {
            for bonus in SilverBonus.allCases {
                if booleans[silverKey(color, bonus: bonus)] == true {
                    total += computeElementCount(bonus.element)
                }
            }
        }
        return total
    }

    private func syncComputedFields() {
        let prefix = "painting_\(paintingNumber)"
        for element in Element.allCases {
            integers["\(prefix)_\(element.rawValue)"] = computeElementCount(element)
        }
        integers["\(prefix)_silver"] = computeSilverRibbons()
    }
}
