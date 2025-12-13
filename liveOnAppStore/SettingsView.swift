import SwiftUI

struct SettingsView: View {
    @Binding var usdToInrRate: Double
    @Environment(\.dismiss) private var dismiss
    @AppStorage("autoConvertNetWorth") private var autoConvertNetWorth: Bool = false
    
    private static let defaultRate: Double = 89.0
    
    private var formatter: NumberFormatter {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 2
        formatter.minimumFractionDigits = 2
        return formatter
    }
    
    @State private var rateString: String
    
    init(usdToInrRate: Binding<Double>) {
        self._usdToInrRate = usdToInrRate
        self._rateString = State(initialValue: Self.formatter.string(from: NSNumber(value: usdToInrRate.wrappedValue)) ?? "")
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section("Currency Conversion") {
                    TextField("USD → INR rate", text: $rateString)
                        .keyboardType(.decimalPad)
                        .onChange(of: rateString) { newValue in
                            if let number = formatter.number(from: newValue)?.doubleValue {
                                usdToInrRate = number
                            }
                        }
                    Text("The exchange rate from US Dollar to Indian Rupee (1 USD equals X INR).")
                        .font(.footnote)
                        .foregroundColor(.secondary)

                    Button("Reset to Default (\(Self.formatter.string(from: NSNumber(value: Self.defaultRate)) ?? "89.00"))") {
                        usdToInrRate = Self.defaultRate
                        rateString = formatter.string(from: NSNumber(value: Self.defaultRate)) ?? ""
                    }
                }
            }
            .navigationTitle("Settings")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        if let number = formatter.number(from: rateString)?.doubleValue {
                            usdToInrRate = number
                        }
                        dismiss()
                    }
                }
            }
        }
    }
    
    private static var formatter: NumberFormatter {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 2
        formatter.minimumFractionDigits = 2
        return formatter
    }
}

struct SettingsView_Previews: PreviewProvider {
    struct Container: View {
        @State private var rate: Double = 83.0
        var body: some View {
            SettingsView(usdToInrRate: $rate)
        }
    }
    static var previews: some View {
        Container()
    }
}
