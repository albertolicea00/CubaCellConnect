import SwiftUI

// MARK: - Code Row

/// One row in the code list: title, description, dialable code and action hint.
/// Tapping the row dials directly — iOS itself asks for confirmation before the call goes through.
struct CodeRowView: View {
    let code: USSDCode

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(code.title)
                    .font(.body.weight(.medium))
                    .foregroundStyle(Color.appForeground)

                Text(code.details)
                    .font(.footnote)
                    .foregroundStyle(.secondary)

                Text(code.code)
                    .font(AppTheme.codeFont(size: 15))
                    .foregroundStyle(Color.brandNavy)

                if let mnemonic = code.mnemonic {
                    Label(mnemonic, systemImage: "lightbulb.fill")
                        .font(.caption2)
                        .foregroundStyle(Color.brandCyan)
                }
            }

            Spacer()

            Image(systemName: code.type == .call ? "phone.fill" : "number")
                .font(.callout)
                .foregroundStyle(.white)
                .frame(width: 32, height: 32)
                .background(Color.brandCyan, in: Circle())
        }
        .padding(.vertical, 6)
    }
}

#Preview(traits: .sizeThatFitsLayout) {
    CodeRowView(code: USSDCode(
        id: "main-balance",
        code: "*222#",
        title: "Main Balance",
        details: "Main balance, voice, SMS and mobile data resources, plus the phone line validity period.",
        category: "balance",
        type: .ussd,
        requiresInput: false,
        inputPlaceholder: nil,
        mnemonic: "328 = DAT (datos)"
    ))
    .padding()
}
