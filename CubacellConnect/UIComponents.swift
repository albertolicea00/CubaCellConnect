import SwiftUI

// MARK: - Code Row

/// One row in the code list: title, dialable code and action hint.
struct CodeRowView: View {
    let code: USSDCode

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(code.title)
                    .font(.body.weight(.medium))
                    .foregroundStyle(Color.appForeground)
                Text(code.code)
                    .font(AppTheme.codeFont(size: 15))
                    .foregroundStyle(Color.brandNavy)
            }
            Spacer()
            Image(systemName: code.type == .call ? "phone.fill" : "number")
                .font(.callout)
                .foregroundStyle(.white)
                .frame(width: 32, height: 32)
                .background(Color.brandCyan, in: Circle())
        }
        .padding(.vertical, 4)
    }
}

#Preview(traits: .sizeThatFitsLayout) {
    CodeRowView(code: USSDCode(
        id: "main-balance",
        code: "*222#",
        title: "Main Balance",
        details: "Main balance and line validity.",
        category: "balance",
        type: .ussd,
        requiresInput: false,
        inputPlaceholder: nil,
        mnemonic: nil
    ))
    .padding()
}
