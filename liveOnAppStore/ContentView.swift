import SwiftUI

struct ContentView: View {
    @State private var netWorthAmount: Double = 500_000.0
    @State private var netWorthProgress: Double = 0.0        // 0.0 ... 1.0 for exponential slider
    @State private var growthRatePercent: Double = 7.00     // 0.00 ... 40.00
    @State private var years: Double = 10.00                // 0.00 ... 200.00
    @State private var growthRateProgress: Double = 0.0       // 0.0 ... 1.0 for exponential growth slider
    @State private var yearsProgress: Double = 0.0             // 0.0 ... 1.0 for exponential years slider
    @State private var currencyCode: String = "USD" // or "INR"
    @State private var outputCurrencyCode: String = "USD"
    @State private var isPressConverting: Bool = false
    @AppStorage("usdToInrRate") private var usdToInrRate: Double = 83.0

    @State private var outputText: String = "Net worth after 10.00 years is: —" {
        didSet { glowActive = true }
    }
    @State private var errorText: String? = nil
    @State private var glowActive: Bool = false       // Glow state

    // New: String bindings for text fields
    @State private var netWorthString: String = ""
    @State private var growthRateString: String = ""
    @State private var yearsString: String = ""

    @FocusState private var focusedField: Field?

    enum Field {
        case netWorth, rate, years
    }

    private var oppositeCurrencyCode: String { currencyCode == "USD" ? "INR" : "USD" }

    // MARK: - Dynamic Currency Icon
    private var currencyIconName: String {
        switch oppositeCurrencyCode {        // Show the icon for the opposite of the top selection
        case "INR": return "indianrupeesign.circle.fill"
        default:    return "dollarsign.circle.fill"
        }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 12) {
                            Text("Inputs")
                                .font(.headline)
                            Spacer()
                            Picker("Currency", selection: $currencyCode) {
                                Text("USA").tag("USD")
                                Text("INDIA").tag("INR")
                            }
                            .pickerStyle(.segmented)
                            .frame(maxWidth: 180)
                            .onChange(of: currencyCode) { _, _ in
                                if !isPressConverting {
                                    outputCurrencyCode = currencyCode
                                    calculate()
                                }
                                netWorthString = formatNetWorthString(amount: netWorthAmount)
                            }
                        }
                    }

                    // Current Net Worth (Text + Slider)
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text("Current net worth")

                            Spacer()

                            TextField("", text: $netWorthString)
                                .keyboardType(.numberPad)
                                .multilineTextAlignment(.trailing)
                                .frame(width: 160)
                                .focused($focusedField, equals: .netWorth)
                                .onSubmit { commitNetWorthString() }
                                .onChange(of: focusedField) { _, newFocus in
                                    if newFocus != .netWorth { commitNetWorthString() }
                                }
                        }

                        Slider(value: $netWorthProgress, in: 0...1)
                            .onChange(of: netWorthProgress) { _, newValue in
                                let mapped = expMap(newValue)
                                let rounded = Double(Int(mapped.rounded()))
                                if rounded != netWorthAmount {
                                    netWorthAmount = rounded
                                    netWorthString = formatNetWorthString(amount: rounded)
                                }
                            }
                    }

                    // Growth Rate (Text + Slider)
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text("Growth rate (%)")

                            Spacer()

                            TextField("", text: $growthRateString)
                                .keyboardType(.decimalPad)
                                .multilineTextAlignment(.trailing)
                                .frame(width: 80)
                                .focused($focusedField, equals: .rate)
                                .onSubmit { commitGrowthRateString() }
                                .onChange(of: focusedField) { _, newFocus in
                                    if newFocus != .rate { commitGrowthRateString() }
                                }
                        }

                        Slider(value: $growthRateProgress, in: 0...1)
                            .onChange(of: growthRateProgress) { _, newValue in
                                let mapped = growthMap(newValue)
                                if mapped != growthRatePercent {
                                    growthRatePercent = mapped
                                    growthRateString = formatGrowthRateString(percent: mapped)
                                }
                            }
                    }

                    // Years (Text + Slider)
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Years for growth")
                                Text(yearsMonthsString(from: years))
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                            }

                            Spacer()

                            TextField("", text: $yearsString)
                                .keyboardType(.decimalPad)
                                .multilineTextAlignment(.trailing)
                                .frame(width: 80)
                                .focused($focusedField, equals: .years)
                                .onSubmit { commitYearsString() }
                                .onChange(of: focusedField) { _, newFocus in
                                    if newFocus != .years { commitYearsString() }
                                }
                        }

                        Slider(value: $yearsProgress, in: 0...1)
                            .onChange(of: yearsProgress) { _, newValue in
                                let mapped = yearsMap(newValue)
                                let snapped = (mapped / yearsStep).rounded() * yearsStep
                                if snapped != years {
                                    years = snapped
                                    yearsString = formatYearsString(years: snapped)
                                }
                                let yp = invYearsMap(snapped)
                                if abs(yp - yearsProgress) > .ulpOfOne { yearsProgress = yp }
                            }
                    }
                }

                // Calculate + Default
                Section {
                    HStack(spacing: 0) {
                        Button(action: calculate) {
                            Text("Calculate")
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                        }
                        .buttonStyle(.plain)

                        Divider().frame(height: 28)

                        Button(action: clear) {
                            Text("Default")
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, 0)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color(uiColor: .secondarySystemFill))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .strokeBorder(.quaternary, lineWidth: 1)
                    )
                    .listRowBackground(Color.clear)
                }

                // Output Section
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(outputText)
                            .font(.title3)
                            .fontWeight(.semibold)

                        if let errorText {
                            Text(errorText)
                                .foregroundStyle(.red)
                        }
                    }
                    .padding(16)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(.regularMaterial)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .strokeBorder(.quaternary, lineWidth: 1)
                    )
                    .listRowBackground(Color.clear)

                } header: {
                    HStack(spacing: 12) {
                        Text("Output")
                            .font(.headline)

                        Spacer()

                        // 🔥 NEW: Dynamic USD / INR icon with glow
                        Image(systemName: currencyIconName)
                            .font(.title3.weight(.semibold))
                            .frame(width: 32, height: 32)
                            .background(Circle().fill(Color.secondary.opacity(0.15)))
                            .overlay(Circle().strokeBorder(.quaternary, lineWidth: 1))
                            .shadow(
                                color: glowActive ? Color.yellow.opacity(0.7) : .clear,
                                radius: glowActive ? 12 : 0
                            )
                            .animation(.easeInOut(duration: 0.35), value: glowActive)
                            .gesture(
                                DragGesture(minimumDistance: 0)
                                    .onChanged { _ in
                                        if !isPressConverting {
                                            isPressConverting = true
                                            outputCurrencyCode = oppositeCurrencyCode
                                            calculate()
                                        }
                                    }
                                    .onEnded { _ in
                                        isPressConverting = false
                                        outputCurrencyCode = currencyCode
                                        calculate()
                                    }
                            )
                            .accessibilityLabel("Opposite currency: \(oppositeCurrencyCode)")
                    }
                }
            }
            .onAppear {
                let p = invExpMap(netWorthAmount)
                if abs(p - netWorthProgress) > .ulpOfOne { netWorthProgress = p }
                let gp = invGrowthMap(growthRatePercent)
                if abs(gp - growthRateProgress) > .ulpOfOne { growthRateProgress = gp }
                let yp = invYearsMap(years)
                if abs(yp - yearsProgress) > .ulpOfOne { yearsProgress = yp }
                netWorthString = formatNetWorthString(amount: netWorthAmount)
                growthRateString = formatGrowthRateString(percent: growthRatePercent)
                yearsString = formatYearsString(years: years)
            }
            .navigationTitle("Net Worth Calculator")
            .toolbar {
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") { focusedField = nil }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    NavigationLink(destination: SettingsView(usdToInrRate: $usdToInrRate)) {
                        Image(systemName: "gearshape")
                    }
                }
            }
        }
    }

    // MARK: - Commit helper methods

    private func commitNetWorthString() {
        let stripped = netWorthString.replacingOccurrences(of: ",", with: "")
        if let value = Double(stripped) {
            let rounded = Double(Int(value.rounded()))
            let clamped = min(max(rounded, 0), netWorthMax)
            netWorthAmount = clamped
            netWorthProgress = invExpMap(clamped)
            netWorthString = formatNetWorthString(amount: clamped)
        } else {
            netWorthString = formatNetWorthString(amount: netWorthAmount)
        }
    }

    private func commitGrowthRateString() {
        let stripped = growthRateString.replacingOccurrences(of: ",", with: "").trimmingCharacters(in: .whitespaces)
        if let value = Double(stripped) {
            let clamped = min(max(value, growthMin), growthMax)
            growthRatePercent = clamped
            growthRateProgress = invGrowthMap(clamped)
            growthRateString = formatGrowthRateString(percent: clamped)
        } else {
            growthRateString = formatGrowthRateString(percent: growthRatePercent)
        }
    }

    private func commitYearsString() {
        let stripped = yearsString.replacingOccurrences(of: ",", with: "").trimmingCharacters(in: .whitespaces)
        if let value = Double(stripped) {
            let clamped = min(max(value, yearsMin), yearsMax)
            let snapped = (clamped / yearsStep).rounded() * yearsStep
            years = snapped
            yearsProgress = invYearsMap(snapped)
            yearsString = formatYearsString(years: snapped)
        } else {
            yearsString = formatYearsString(years: years)
        }
    }

    // MARK: - String Formatting Helpers
    private func formatNetWorthString(amount: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.usesGroupingSeparator = true
        formatter.maximumFractionDigits = 0
        formatter.minimumFractionDigits = 0
        let localeIdentifier: String
        switch currencyCode {
        case "INR": localeIdentifier = "en_IN"
        default:    localeIdentifier = "en_US"
        }
        formatter.locale = Locale(identifier: localeIdentifier)
        return formatter.string(from: NSNumber(value: amount)) ?? String(Int(amount))
    }
    private func formatGrowthRateString(percent: Double) -> String {
        let nf = NumberFormatter()
        nf.numberStyle = .decimal
        nf.minimumFractionDigits = 2
        nf.maximumFractionDigits = 2
        return nf.string(from: NSNumber(value: percent)) ?? String(format: "%.2f", percent)
    }
    private func formatYearsString(years: Double) -> String {
        let nf = NumberFormatter()
        nf.numberStyle = .decimal
        nf.minimumFractionDigits = 2
        nf.maximumFractionDigits = 2
        return nf.string(from: NSNumber(value: years)) ?? String(format: "%.2f", years)
    }

    // MARK: - Slider Mapping (Exponential 0...10M)

    private var netWorthMax: Double { currencyCode == "USD" ? 50_000_000 : 5_000_000_000 }
    private var netWorthCurveK: Double {
        let targetMid: Double = 500_000
        let ratio = max(min(targetMid / netWorthMax, 0.999999), 0.000001)
        let K = solveKForMidpoint(ratio: ratio)
        return K
    }

    private func solveKForMidpoint(ratio: Double) -> Double {
        var k = 6.0
        for _ in 0..<20 {
            let eK = exp(k)
            let eK2 = exp(k * 0.5)
            let denom = eK - 1.0
            if abs(denom) < 1e-12 { break }
            let f = (eK2 - 1.0) / denom - ratio
            let df = ((0.5 * eK2) * denom - (eK2 - 1.0) * eK) / (denom * denom)
            if abs(df) < 1e-12 { break }
            let step = f / df
            k -= step
            if abs(step) < 1e-8 { break }
        }
        return max(0.1, min(k, 50.0))
    }

    private func expMap(_ t: Double) -> Double {
        let denom = exp(netWorthCurveK) - 1
        guard denom != 0 else { return t * netWorthMax }
        return netWorthMax * ((exp(netWorthCurveK * t) - 1) / denom)
    }

    private func invExpMap(_ v: Double) -> Double {
        let denom = exp(netWorthCurveK) - 1
        guard denom != 0 else { return (v / netWorthMax) }
        let x = (v / netWorthMax) * denom + 1
        return log(x) / netWorthCurveK
    }

    // MARK: - Growth Slider Mapping

    private let growthMin: Double = 0.1
    private let growthMax: Double = 50.0

    private var growthControlC: Double {
        let gMid = (log(8.0) - log(growthMin)) / (log(growthMax) - log(growthMin))
        return max(0.0, min(1.0, 2.0 * (gMid - 0.25)))
    }

    private func bezierG(_ t: Double, _ c: Double) -> Double {
        let A = (1.0 - 2.0 * c)
        let B = (2.0 * c)
        return A * t * t + B * t
    }

    private func growthMap(_ t: Double) -> Double {
        let g = bezierG(min(max(t, 0), 1), growthControlC)
        let lnMin = log(growthMin)
        let lnMax = log(growthMax)
        return exp(lnMin + g * (lnMax - lnMin))
    }

    private func invGrowthMap(_ v: Double) -> Double {
        let clampedV = min(max(v, growthMin), growthMax)
        let lnMin = log(growthMin)
        let lnMax = log(growthMax)
        let g = (log(clampedV) - lnMin) / (lnMax - lnMin)
        let c = growthControlC
        let A = (1.0 - 2.0 * c)
        let B = (2.0 * c)
        let C = -g
        if abs(A) < 1e-9 { return min(max(g / B, 0), 1) }
        let disc = max(0, B * B - 4 * A * C)
        let sqrtDisc = sqrt(disc)
        let t1 = (-B + sqrtDisc) / (2 * A)
        let t2 = (-B - sqrtDisc) / (2 * A)
        let candidates = [t1, t2].filter { $0.isFinite && $0 >= 0 && $0 <= 1 }
        return candidates.first ?? min(max(g, 0), 1)
    }

    // MARK: - Years Slider Mapping

    private let yearsMin: Double = 0.0
    private let yearsMax: Double = 200.0

    private func yearsMap(_ t: Double) -> Double {
        let clampedT = min(max(t, 0), 1)
        let scaled = exp(clampedT * log1p(yearsMax - yearsMin)) - 1
        return yearsMin + scaled
    }

    private func invYearsMap(_ v: Double) -> Double {
        let clampedV = min(max(v, yearsMin), yearsMax)
        return (log1p(clampedV - yearsMin)) / log1p(yearsMax - yearsMin)
    }

    private let daysPerYear: Double = 365.0
    private var yearsStep: Double { 30.0 / daysPerYear }

    private func yearsMonthsString(from yearsValue: Double) -> String {
        let totalMonths = Int((yearsValue * 12).rounded())
        let y = totalMonths / 12
        let m = totalMonths % 12
        switch (y, m) {
        case (0,0): return "0 years"
        case (_,0): return "\(y) year\(y == 1 ? "" : "s")"
        case (0,_): return "\(m) month\(m == 1 ? "" : "s")"
        default:    return "\(y) year\(y == 1 ? "" : "s"), \(m) month\(m == 1 ? "" : "s")"
        }
    }

    private func currencylessNumberFormatter() -> NumberFormatter {
        let nf = NumberFormatter()
        nf.numberStyle = .decimal
        nf.usesGroupingSeparator = true
        nf.maximumFractionDigits = 0
        nf.minimumFractionDigits = 0
        nf.locale = Locale(identifier: currencyCode == "INR" ? "en_IN" : "en_US")
        return nf
    }

    // MARK: - Calculation

    private func calculate() {
        focusedField = nil
        errorText = nil

        guard netWorthAmount >= 0 else {
            outputText = "Net worth after \(formattedYears()) years is: —"
            errorText = "Please enter a valid current net worth."
            return
        }

        let r = growthRatePercent / 100.0
        let n = 4.0
        let t = years

        let futureValueUSD = netWorthAmount * pow(1.0 + (r / n), n * t)
        let displayValue = (outputCurrencyCode == "USD")
            ? futureValueUSD
            : futureValueUSD * usdToInrRate

        outputText =
            "Net worth after \(formattedYears()) years is: \(currencyString(displayValue, currencyCode: outputCurrencyCode))"
    }

    private func clear() {
        focusedField = nil
        netWorthAmount = 500_000.0
        netWorthProgress = invExpMap(500_000.0)
        growthRatePercent = 7.00
        growthRateProgress = invGrowthMap(7.00)
        years = 10.00
        yearsProgress = invYearsMap(10.00)
        outputCurrencyCode = "USD"
        outputText = "Net worth after 10.00 years is: —"
        errorText = nil
        glowActive = false

        netWorthString = formatNetWorthString(amount: netWorthAmount)
        growthRateString = formatGrowthRateString(percent: growthRatePercent)
        yearsString = formatYearsString(years: years)
        
        calculate()
    }

    private func formattedYears() -> String {
        String(format: "%.2f", years)
    }

    private func currencyString(_ value: Double) -> String {
        currencyString(value, currencyCode: currencyCode)
    }

    private func currencyString(_ value: Double, currencyCode: String) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = currencyCode
        formatter.maximumFractionDigits = 2
        formatter.minimumFractionDigits = 2
        return formatter.string(from: NSNumber(value: value))
            ?? String(format: "%.2f", value)
    }
}

#Preview {
    ContentView()
}

