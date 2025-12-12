import SwiftUI

struct ContentView: View {
    @State private var netWorthText: String = ""
    @State private var growthRatePercent: Double = 7.00     // 0.00 ... 40.00
    @State private var years: Double = 10.00                // 0.00 ... 200.00

    @State private var outputText: String = "Net worth after 10.00 years is: —"
    @State private var errorText: String? = nil

    @FocusState private var focusedField: Field?

    enum Field {
        case netWorth, rate, years
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Inputs") {

                    // Current Net Worth
                    TextField("Current net worth (e.g., 150000.00)", text: $netWorthText)
                        .keyboardType(.decimalPad)
                        .focused($focusedField, equals: .netWorth)

                    // Growth Rate (Text + Slider) test 1
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text("Growth rate (%)")

                            Spacer()

                            TextField(
                                "",
                                value: $growthRatePercent,
                                format: .number.precision(.fractionLength(2))
                            )
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 80)
                            .focused($focusedField, equals: .rate)
                            .onChange(of: growthRatePercent) { _, newValue in
                                growthRatePercent = min(max(newValue, 0), 40)
                            }
                        }

                        Slider(value: $growthRatePercent, in: 0...40, step: 0.25)
                    }

                    // Years (Text + Slider)
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text("Years for growth")

                            Spacer()

                            TextField(
                                "",
                                value: $years,
                                format: .number.precision(.fractionLength(2))
                            )
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 80)
                            .focused($focusedField, equals: .years)
                            .onChange(of: years) { _, newValue in
                                years = min(max(newValue, 0), 200)
                            }
                        }

                        Slider(value: $years, in: 0...200, step: 0.25)
                    }
                }

                Section {
                    Button("Calculate") { calculate() }
                        .frame(maxWidth: .infinity)

                    Button("Clear") { clear() }
                        .frame(maxWidth: .infinity)
                        .foregroundStyle(.secondary)
                }

                Section("Output") {
                    Text(outputText)
                        .font(.title3)

                    if let errorText {
                        Text(errorText)
                            .foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle("Net Worth Calculator")
            .toolbar {
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") { focusedField = nil }
                }
            }
        }
    }

    // MARK: - Calculation

    private func calculate() {
        focusedField = nil
        errorText = nil

        let raw = netWorthText
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: ",", with: "")

        guard let principal = Double(raw), principal >= 0 else {
            outputText = "Net worth after \(formattedYears()) years is: —"
            errorText = "Please enter a valid current net worth."
            return
        }

        let r = growthRatePercent / 100.0
        let n = 4.0
        let t = years

        let futureValue = principal * pow(1.0 + (r / n), n * t)

        outputText = "Net worth after \(formattedYears()) years is: \(currencyString(futureValue))"
    }

    private func clear() {
        focusedField = nil
        netWorthText = ""
        growthRatePercent = 7.00
        years = 10.00
        outputText = "Net worth after 10.00 years is: —"
        errorText = nil
    }

    // MARK: - Formatting

    private func formattedYears() -> String {
        String(format: "%.2f", years)
    }

    private func currencyString(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.maximumFractionDigits = 2
        formatter.minimumFractionDigits = 2
        return formatter.string(from: NSNumber(value: value))
            ?? String(format: "%.2f", value)
    }
}

#Preview {
    ContentView()
}
