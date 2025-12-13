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

    @State private var outputText: String = "Net worth after 10.00 years is: —"
    @State private var errorText: String? = nil

    @FocusState private var focusedField: Field?

    enum Field {
        case netWorth, rate, years
    }

    private var oppositeCurrencyCode: String { currencyCode == "USD" ? "INR" : "USD" }

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
                            }
                        }
                    }

                    // Current Net Worth (Text + Slider)
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text("Current net worth")

                            Spacer()

                            TextField(
                                "",
                                value: $netWorthAmount,
                                formatter: currencylessNumberFormatter()
                            )
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 160)
                            .focused($focusedField, equals: .netWorth)
                            .onChange(of: netWorthAmount) { _, newValue in
                                let clamped = min(max(newValue, 0), netWorthMax)
                                if clamped != netWorthAmount { netWorthAmount = clamped }
                                let p = invExpMap(clamped)
                                if abs(p - netWorthProgress) > .ulpOfOne { netWorthProgress = p }
                            }
                        }

                        Slider(value: $netWorthProgress, in: 0...1)
                            .onChange(of: netWorthProgress) { _, newValue in
                                let mapped = expMap(newValue)
                                if mapped != netWorthAmount { netWorthAmount = mapped }
                            }
                    }

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
                                growthRatePercent = min(max(newValue, growthMin), growthMax)
                                let p = invGrowthMap(growthRatePercent)
                                if abs(p - growthRateProgress) > .ulpOfOne { growthRateProgress = p }
                            }
                        }

                        Slider(value: $growthRateProgress, in: 0...1)
                            .onChange(of: growthRateProgress) { _, newValue in
                                let mapped = growthMap(newValue)
                                if mapped != growthRatePercent { growthRatePercent = mapped }
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
                                let snappedYears = (years / yearsStep).rounded() * yearsStep
                                if snappedYears != years { years = snappedYears }
                                let yp = invYearsMap(years)
                                if abs(yp - yearsProgress) > .ulpOfOne { yearsProgress = yp }
                            }
                        }

                        Slider(value: $yearsProgress, in: 0...1)
                            .onChange(of: yearsProgress) { _, newValue in
                                let mapped = yearsMap(newValue)
                                let snapped = (mapped / yearsStep).rounded() * yearsStep
                                if snapped != years { years = snapped }
                                // keep slider aligned to snapped value
                                let yp = invYearsMap(snapped)
                                if abs(yp - yearsProgress) > .ulpOfOne { yearsProgress = yp }
                            }
                    }
                }

                Section {
                    HStack(spacing: 0) {
                        Button(action: calculate) {
                            Text("Calculate")
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                        }
                        .buttonStyle(.plain)
                        .contentShape(Rectangle())

                        Divider()
                            .frame(height: 28)

                        Button(action: clear) {
                            Text("Default")
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                        }
                        .buttonStyle(.plain)
                        .contentShape(Rectangle())
                    }
                    .padding(.horizontal, 0)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(Color(uiColor: .secondarySystemFill))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .strokeBorder(.quaternary, lineWidth: 1)
                    )
                    .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                    .listRowBackground(Color.clear)
                }

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
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(.regularMaterial)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .strokeBorder(.quaternary, lineWidth: 1)
                    )
                    .listRowBackground(Color.clear)
                } header: {
                    HStack(spacing: 12) {
                        Text("Output")
                            .font(.headline)
                        Spacer()
                        // Round symbol showing opposite currency; press and hold to temporarily convert
                        Text(oppositeCurrencyCode == "USD" ? "$" : "₹")
                            .font(.subheadline.weight(.semibold))
                            .frame(width: 32, height: 32)
                            .background(Circle().fill(Color.secondary.opacity(0.15)))
                            .overlay(Circle().strokeBorder(.quaternary, lineWidth: 1))
                            .contentShape(Circle())
                            .gesture(
                                DragGesture(minimumDistance: 0)
                                    .onChanged { _ in
                                        if !isPressConverting {
                                            isPressConverting = true
                                            outputCurrencyCode = oppositeCurrencyCode
                                            // Recalculate outputText in new currency
                                            calculate()
                                        }
                                    }
                                    .onEnded { _ in
                                        isPressConverting = false
                                        // Revert display currency back to base (selected location)
                                        outputCurrencyCode = currencyCode
                                        calculate()
                                    }
                            )
                            .accessibilityLabel("Hold to view in \(oppositeCurrencyCode)")
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

    // MARK: - Slider Mapping (Exponential 0...10M)

    private var netWorthMax: Double { currencyCode == "USD" ? 50_000_000 : 5_000_000_000 }
    private var netWorthCurveK: Double {
        // Choose K so that when USD is selected, 500K sits at progress 0.5 (center).
        // For INR, keep the same K to preserve similar feel across currencies.
        // Derivation: expMap(0.5) = targetMid -> (exp(K*t)-1)/(exp(K)-1) = targetMid/netWorthMax
        let targetMid: Double = 500_000 // Center for USD; reused for INR for consistent feel.
        let ratio = max(min(targetMid / netWorthMax, 0.999999), 0.000001)
        // Solve for K numerically (Newton-Raphson) for stability.
        let K = solveKForMidpoint(ratio: ratio)
        return K
    }

    // Solve K such that f(0.5; K) = ratio where f(t;K) = (exp(K*t)-1)/(exp(K)-1)
    private func solveKForMidpoint(ratio: Double) -> Double {
        // Initial guess near 6.0 works well
        var k = 6.0
        for _ in 0..<20 {
            let eK = exp(k)
            let eK2 = exp(k * 0.5)
            let denom = eK - 1.0
            if abs(denom) < 1e-12 { break }
            let f = (eK2 - 1.0) / denom - ratio
            // derivative df/dk
            let df = ((0.5 * eK2) * denom - (eK2 - 1.0) * eK) / (denom * denom)
            if abs(df) < 1e-12 { break }
            let step = f / df
            k -= step
            if abs(step) < 1e-8 { break }
        }
        return max(0.1, min(k, 50.0))
    }

    private func expMap(_ t: Double) -> Double {
        // t in 0...1 -> value in 0...netWorthMax (exponential easing)
        let denom = exp(netWorthCurveK) - 1
        guard denom != 0 else { return t * netWorthMax }
        return netWorthMax * ((exp(netWorthCurveK * t) - 1) / denom)
    }

    private func invExpMap(_ v: Double) -> Double {
        // v in 0...netWorthMax -> t in 0...1
        let denom = exp(netWorthCurveK) - 1
        guard denom != 0 else { return (v / netWorthMax) }
        let x = (v / netWorthMax) * denom + 1
        return log(x) / netWorthCurveK
    }

    // MARK: - Growth Slider Mapping (Exponential 0.1% ... 50%, center ~ 8%)

    private let growthMin: Double = 0.1
    private let growthMax: Double = 50.0

    // Quadratic Bezier shaping so that t=0.5 maps to 8%
    private var growthControlC: Double {
        let gMid = (log(8.0) - log(growthMin)) / (log(growthMax) - log(growthMin))
        return max(0.0, min(1.0, 2.0 * (gMid - 0.25)))
    }

    private func bezierG(_ t: Double, _ c: Double) -> Double {
        // Quadratic Bezier from 0 to 1 with control c (0..1)
        // g(t) = (1 - 2c) t^2 + 2c t
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
        // Convert value to normalized g in [0,1] via log scale, then invert Bezier
        let clampedV = min(max(v, growthMin), growthMax)
        let lnMin = log(growthMin)
        let lnMax = log(growthMax)
        let g = (log(clampedV) - lnMin) / (lnMax - lnMin)
        let c = growthControlC
        let A = (1.0 - 2.0 * c)
        let B = (2.0 * c)
        let C = -g
        if abs(A) < 1e-9 { // nearly linear
            return min(max(g / B, 0), 1)
        }
        let disc = max(0, B * B - 4 * A * C)
        let sqrtDisc = sqrt(disc)
        let t1 = (-B + sqrtDisc) / (2 * A)
        let t2 = (-B - sqrtDisc) / (2 * A)
        // pick the root in [0,1]
        let candidates = [t1, t2].filter { $0.isFinite && $0 >= 0 && $0 <= 1 }
        return candidates.first ?? min(max(g, 0), 1)
    }

    // MARK: - Years Slider Mapping (Exponential 0 ... 200, default 10)

    private let yearsMin: Double = 0.0
    private let yearsMax: Double = 200.0

    private func yearsMap(_ t: Double) -> Double {
        // Exponential-like mapping using log1p to handle zero nicely
        let clampedT = min(max(t, 0), 1)
        let scaled = exp(clampedT * log1p(yearsMax - yearsMin)) - 1
        return yearsMin + scaled
    }

    private func invYearsMap(_ v: Double) -> Double {
        let clampedV = min(max(v, yearsMin), yearsMax)
        return (log1p(clampedV - yearsMin)) / log1p(yearsMax - yearsMin)
    }
    
    // Years snapping: 30-day increments
    private let daysPerYear: Double = 365.0
    private var yearsStep: Double { 30.0 / daysPerYear }
    
    // MARK: - Display Helpers
    private func yearsMonthsString(from yearsValue: Double) -> String {
        let totalMonths = Int((yearsValue * 12).rounded())
        let y = totalMonths / 12
        let m = totalMonths % 12
        switch (y, m) {
        case (0, 0):
            return "0 years"
        case (_, 0):
            return "\(y) year\(y == 1 ? "" : "s")"
        case (0, _):
            return "\(m) month\(m == 1 ? "" : "s")"
        default:
            return "\(y) year\(y == 1 ? "" : "s"), \(m) month\(m == 1 ? "" : "s")"
        }
    }
    
    // MARK: - Number Formatting Helpers
    private func currencylessNumberFormatter() -> NumberFormatter {
        let nf = NumberFormatter()
        nf.numberStyle = .decimal
        nf.usesGroupingSeparator = true
        nf.maximumFractionDigits = 2
        nf.minimumFractionDigits = 2
        // Configure locale/grouping to match currency selection while omitting the symbol
        let localeIdentifier: String
        switch currencyCode {
        case "INR":
            localeIdentifier = "en_IN"
        default:
            localeIdentifier = "en_US"
        }
        nf.locale = Locale(identifier: localeIdentifier)
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

        let displayValue: Double = (outputCurrencyCode == "USD") ? futureValueUSD : futureValueUSD * usdToInrRate

        outputText = "Net worth after \(formattedYears()) years is: \(currencyString(displayValue, currencyCode: outputCurrencyCode))"
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
    }

    // MARK: - Formatting

    private func formattedYears() -> String {
        String(format: "%.2f", years)
    }

    private func currencyString(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = currencyCode
        formatter.maximumFractionDigits = 2
        formatter.minimumFractionDigits = 2
        return formatter.string(from: NSNumber(value: value))
            ?? String(format: "%.2f", value)
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

