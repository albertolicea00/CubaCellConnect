import SwiftUI

// MARK: - Home Screen

/// Main screen: service codes grouped by category.
struct HomeView: View {
    @Environment(USSDCodeStore.self) private var store
    @State private var selectedCode: USSDCode?

    var body: some View {
        NavigationStack {
            List {
                ForEach(store.categories) { category in
                    Section {
                        ForEach(store.codes(in: category)) { code in
                            CodeRowView(code: code)
                                .contentShape(Rectangle())
                                .onTapGesture { selectedCode = code }
                        }
                    } header: {
                        Label(category.name, systemImage: category.icon)
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(Color.brandCyan)
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("CubaCell Connect")
            .toolbarBackground(Color.brandNavy, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .sheet(item: $selectedCode) { code in
                CodeDetailView(code: code)
                    .presentationDetents([.medium, .large])
                    .presentationDragIndicator(.visible)
            }
        }
        .tint(.brandCyan)
    }
}

#Preview {
    HomeView()
        .environment(USSDCodeStore())
}

// MARK: - Code Detail Sheet

/// Detail sheet for a code: description, optional input field, copy and dial actions.
struct CodeDetailView: View {
    let code: USSDCode

    @State private var input = ""
    @State private var copied = false
    @Environment(\.dismiss) private var dismiss

    private var resolvedCode: String {
        code.resolvedCode(input: input.trimmingCharacters(in: .whitespaces))
    }

    private var isDialDisabled: Bool {
        code.requiresInput && input.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            header

            Text(code.details)
                .font(.body)
                .foregroundStyle(Color.appForeground)

            if let mnemonic = code.mnemonic {
                Label(mnemonic, systemImage: "lightbulb.fill")
                    .font(.footnote)
                    .foregroundStyle(Color.brandCyan)
            }

            if code.requiresInput {
                TextField(code.inputPlaceholder ?? "Input", text: $input)
                    .keyboardType(.phonePad)
                    .textFieldStyle(.roundedBorder)
                    .font(AppTheme.codeFont(size: 16))
            }

            Spacer()

            actions
        }
        .padding(24)
        .background(Color.appBackground)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(code.title)
                .font(.title2.bold())
                .foregroundStyle(Color.brandNavy)
            Text(resolvedCode)
                .font(AppTheme.codeFont(size: 22))
                .foregroundStyle(.white)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(Color.brandNavy, in: RoundedRectangle(cornerRadius: 10))
        }
    }

    private var actions: some View {
        HStack(spacing: 12) {
            Button {
                UIPasteboard.general.string = resolvedCode
                copied = true
            } label: {
                Label(copied ? "Copied" : "Copy", systemImage: copied ? "checkmark" : "doc.on.doc")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .tint(.brandNavy)

            Button {
                DialService.dial(resolvedCode)
                dismiss()
            } label: {
                Label(code.type == .call ? "Call" : "Dial", systemImage: "phone.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(.brandCyan)
            .disabled(isDialDisabled)
        }
        .controlSize(.large)
    }
}

#Preview {
    CodeDetailView(code: USSDCode(
        id: "recharge-card",
        code: "*662*{input}#",
        title: "Recharge with Card",
        details: "Manually recharge your balance with a scratch card.",
        category: "purchase",
        type: .ussd,
        requiresInput: true,
        inputPlaceholder: "Card number",
        mnemonic: nil
    ))
}
