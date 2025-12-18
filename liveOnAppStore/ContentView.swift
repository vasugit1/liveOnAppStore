import SwiftUI

struct ContentView: View {
    enum Compounding: String, CaseIterable, Identifiable {
        case none = "None"
        case monthly = "Monthly"
        case quarterly = "Quarterly"
        case yearly = "Yearly"
        var id: String { self.rawValue }
    }
    
    @State private var netWorthAmount: Double = 500_000.0
    @State private var netWorthProgress: Double = 0.0        // 0.0 ... 1.0 for exponential slider
    @State private var growthRatePercent: Double = 7.00     // 0.00 ... 40.00
    @State private var months: Double = 120                // 0 ... 2400 months (10 years)
    @State private var growthRateProgress: Double = 0.0       // 0.0 ... 1.0 for exponential growth slider
    @State private var monthsProgress: Double = 0.0             // 0.0 ... 1.0 for exponential months slider
    @State private var currencyCode: String = "USD" // or "INR"
    @State private var outputCurrencyCode: String = "USD"
    @State private var isPressConverting: Bool = false
    @AppStorage("usdToInrRate") private var usdToInrRate: Double = 83.0
    
    @State private var outputText: String = "Value after 120 months is: —" {
        didSet { glowActive = true }
    }
    @State private var errorText: String? = nil
    @State private var glowActive: Bool = false       // Glow state
    
    // New: String bindings for text fields
    @State private var netWorthString: String = ""
    @State private var growthRateString: String = ""
    @State private var monthsString: String = ""
    
    @State private var compounding: Compounding = .monthly
    
    @FocusState private var focusedField: Field?
    
    enum Field {
        case netWorth, rate, months
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
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 8) {
                            Text("Location")
                                .font(.headline)
                            Spacer()
                            Picker("Currency", selection: $currencyCode) {
                                Label {
                                    Text("🇺🇸")
                                } icon: {
                                    Color.blue.frame(width: 12, height: 12).clipShape(Circle())
                                }
                                .tag("USD")
                                
                                Label {
                                    Text("🇮🇳")
                                } icon: {
                                    Color.orange.frame(width: 12, height: 12).clipShape(Circle())
                                }
                                .tag("INR")
                            }
                            .pickerStyle(.segmented)
                            .frame(maxWidth: 180)
                            .onChange(of: currencyCode) { _, _ in
                                // When switching input currency, netWorthAmount is NOT converted.
                                // Update netWorthString and netWorthProgress to match unchanged netWorthAmount,
                                // so UI remains stable when switching currencies.
                                if !isPressConverting {
                                    outputCurrencyCode = currencyCode
                                    calculate()
                                }
                                // Refresh the net worth string to update comma formatting for Indian/US style.
                                netWorthString = formatNetWorthString(amount: netWorthAmount)
                                netWorthProgress = invExpMap(netWorthAmount)
                            }
                        }
                    }
                    
                    // Current Net Worth (Text + Slider)
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 2) {
                            Text("Current value")
                            Group {
                                if currencyCode == "INR" {
                                    Image(systemName: "indianrupeesign.circle")
                                } else {
                                    Image(systemName: "dollarsign.circle")
                                }
                            }
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            
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
                    
                    // Growth Rate (Text + Slider) test 1
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 2) {
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
                    
                    // Months (Text + Slider)
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 2) {
                            VStack(alignment: .leading, spacing: 1) {
                                Text("Time invested")
                                Text(yearsStringForDisplay(from: months))
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                            }
                            
                            Spacer()
                            
                            TextField("", text: $monthsString)
                                .keyboardType(.numberPad)
                                .multilineTextAlignment(.trailing)
                                .frame(width: 80)
                                .focused($focusedField, equals: .months)
                                .onSubmit { commitMonthsString() }
                                .onChange(of: focusedField) { _, newFocus in
                                    if newFocus != .months { commitMonthsString() }
                                }
                        }
                        
                        Slider(value: $monthsProgress, in: 0...1)
                            .onChange(of: monthsProgress) { _, newValue in
                                let mapped = monthsMap(newValue)
                                let snapped = Double(Int(mapped.rounded()))
                                if snapped != months {
                                    months = snapped
                                    monthsString = formatMonthsString(months: snapped)
                                }
                                let mp = invMonthsMap(snapped)
                                if abs(mp - monthsProgress) > .ulpOfOne { monthsProgress = mp }
                            }
                    }
                }
                .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
                
                HStack(alignment: .top, spacing: 16) {
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach([Compounding.none, Compounding.quarterly], id: \.self) { type in
                            Button(action: { compounding = type }) {
                                HStack(spacing: 6) {
                                    Image(systemName: compounding == type ? "checkmark.square" : "square")
                                        .foregroundColor(compounding == type ? .accentColor : .secondary)
                                    Text(type.rawValue)
                                        .foregroundColor(.primary)
                                }
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel(type.rawValue)
                        }
                    }
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach([Compounding.monthly, Compounding.yearly], id: \.self) { type in
                            Button(action: { compounding = type }) {
                                HStack(spacing: 6) {
                                    Image(systemName: compounding == type ? "checkmark.square" : "square")
                                        .foregroundColor(compounding == type ? .accentColor : .secondary)
                                    Text(type.rawValue)
                                        .foregroundColor(.primary)
                                }
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel(type.rawValue)
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.vertical, 2)
                .padding(.bottom, 2)
                .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 16))
                
                // Calculate + Default
                Section {
                    HStack(spacing: 0) {
                        Button(action: calculate) {
                            Text("Calculate")
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10)
                        }
                        .buttonStyle(.plain)
                        
                        Divider().frame(height: 28)
                        
                        Button(action: clear) {
                            Text("Default")
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10)
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
                .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 16))
                
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
                let mp = invMonthsMap(months)
                if abs(mp - monthsProgress) > .ulpOfOne { monthsProgress = mp }
                netWorthString = formatNetWorthString(amount: netWorthAmount)
                growthRateString = formatGrowthRateString(percent: growthRatePercent)
                monthsString = formatMonthsString(months: months)
            }
            .navigationTitle("Future Valuator")
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
    
    private func commitMonthsString() {
        let stripped = monthsString.replacingOccurrences(of: ",", with: "").trimmingCharacters(in: .whitespaces)
        if let value = Double(stripped) {
            let clamped = min(max(value, monthsMin), monthsMax)
            let snapped = Double(Int(clamped.rounded()))
            months = snapped
            monthsProgress = invMonthsMap(snapped)
            monthsString = formatMonthsString(months: snapped)
        } else {
            monthsString = formatMonthsString(months: months)
        }
    }
    
    // MARK: - String Formatting Helpers
    private func formatNetWorthString(amount: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.usesGroupingSeparator = true
        formatter.maximumFractionDigits = 0
        formatter.minimumFractionDigits = 0
        // Use en_IN locale to format numbers with Indian comma grouping when INR is selected.
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
    private func formatMonthsString(months: Double) -> String {
        let nf = NumberFormatter()
        nf.numberStyle = .decimal
        nf.maximumFractionDigits = 0
        nf.minimumFractionDigits = 0
        return nf.string(from: NSNumber(value: Int(months))) ?? String(Int(months))
    }
    private func monthsStringForDisplay(from monthsValue: Double) -> String {
        let m = Int(monthsValue.rounded())
        if m == 0 {
            return "0 months"
        } else if m == 1 {
            return "1 month"
        } else {
            return "\(m) months"
        }
    }
    
    private func yearsStringForDisplay(from monthsValue: Double) -> String {
        let years = monthsValue / 12.0
        if years == Double(Int(years)) {
            return "\(Int(years)) year\(Int(years) == 1 ? "" : "s")"
        } else {
            return String(format: "%.1f years", years)
        }
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
    
    // MARK: - Months Slider Mapping (Exponential mapping so 0.5 maps to 120 months)
    
    private let monthsMin: Double = 0.0
    private let monthsMax: Double = 2400.0
    private let monthsMid: Double = 120.0
    
    private var monthsCurveK: Double {
        let ratio = max(min(monthsMid / monthsMax, 0.999999), 0.000001)
        return solveKForMidpoint(ratio: ratio)
    }
    
    private func monthsMap(_ t: Double) -> Double {
        let clampedT = min(max(t, 0), 1)
        let denom = exp(monthsCurveK) - 1
        guard denom != 0 else { return monthsMin + clampedT * (monthsMax - monthsMin) }
        return monthsMax * ((exp(monthsCurveK * clampedT) - 1) / denom)
    }
    
    private func invMonthsMap(_ v: Double) -> Double {
        let clampedV = min(max(v, monthsMin), monthsMax)
        let denom = exp(monthsCurveK) - 1
        guard denom != 0 else { return (clampedV - monthsMin) / (monthsMax - monthsMin) }
        let x = (clampedV / monthsMax) * denom + 1
        return log(x) / monthsCurveK
    }
    
    private let monthsStep: Double = 1.0
    
    // MARK: - Calculation
    
    private func calculate() {
        focusedField = nil
        errorText = nil
        
        guard netWorthAmount >= 0 else {
            outputText = "Value after \(Int(months)) months is: —"
            errorText = "Please enter a valid current net worth."
            return
        }
        
        let r = growthRatePercent / 100.0
        let n: Double
        switch compounding {
        case .none: n = 0
        case .monthly: n = 12
        case .quarterly: n = 4
        case .yearly: n = 1
        }
        let t = months / 12.0
        
        let futureValueUSD: Double
        if n == 0 {
            futureValueUSD = netWorthAmount * (1.0 + r * t)
        } else {
            futureValueUSD = netWorthAmount * pow(1.0 + (r / n), n * t)
        }
        
        let displayValue: Double
        if isPressConverting {
            if outputCurrencyCode == "INR" {
                displayValue = futureValueUSD * usdToInrRate
            } else {
                displayValue = futureValueUSD / usdToInrRate
            }
        } else {
            displayValue = futureValueUSD
        }
        
        outputText =
            "Value after \(Int(months)) months is: \(currencyString(displayValue, currencyCode: outputCurrencyCode))"
    }
    
    private func clear() {
        focusedField = nil
        netWorthAmount = 500_000.0
        netWorthProgress = invExpMap(500_000.0)
        growthRatePercent = 7.00
        growthRateProgress = invGrowthMap(7.00)
        months = 120.0
        monthsProgress = invMonthsMap(120.0)
        outputCurrencyCode = "USD"
        outputText = "Value after 120 months is: —"
        errorText = nil
        glowActive = false
        compounding = .monthly
        
        netWorthString = formatNetWorthString(amount: netWorthAmount)
        growthRateString = formatGrowthRateString(percent: growthRatePercent)
        monthsString = formatMonthsString(months: months)
        
        calculate()
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
        // Use en_IN locale for INR, en_US for USD
        let localeIdentifier: String
        switch currencyCode {
        case "INR": localeIdentifier = "en_IN"
        default:    localeIdentifier = "en_US"
        }
        formatter.locale = Locale(identifier: localeIdentifier)
        return formatter.string(from: NSNumber(value: value))
            ?? String(format: "%.2f", value)
    }
}

#Preview {
    ContentView()
}

