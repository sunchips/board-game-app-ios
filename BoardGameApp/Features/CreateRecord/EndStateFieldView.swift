import SwiftUI

struct EndStateFieldView: View {
    let field: EndStateField
    @Binding var integers: [String: Int]
    @Binding var booleans: [String: Bool]

    var body: some View {
        switch field {
        case let .integer(key, label, min, max):
            Stepper(
                value: Binding(
                    get: { integers[key] ?? min },
                    set: { integers[key] = $0 },
                ),
                in: (min)...(max ?? 999),
            ) {
                LabeledContent(label, value: "\(integers[key] ?? min)")
            }
        case let .boolean(key, label):
            Toggle(
                label,
                isOn: Binding(
                    get: { booleans[key] ?? false },
                    set: { booleans[key] = $0 },
                ),
            )
        }
    }
}
