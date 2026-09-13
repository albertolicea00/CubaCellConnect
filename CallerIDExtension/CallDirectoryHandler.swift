import CallKit

/// Labels incoming `*99` collect calls with the real contact's name. The main app writes the
/// wrapped-number → name list (`CallerIDStore`) from the device's Contacts; this extension only
/// reads that shared list and hands it to CallKit — it has no Contacts access of its own.
final class CallDirectoryHandler: CXCallDirectoryProvider {
    override func beginRequest(with context: CXCallDirectoryExtensionContext) {
        context.delegate = self

        // CallKit requires entries added in strictly ascending numeric order.
        let entries = CallerIDStore.read().sorted { $0.wrappedNumber < $1.wrappedNumber }
        for entry in entries {
            context.addIdentificationEntry(
                withNextSequentialPhoneNumber: CXCallDirectoryPhoneNumber(entry.wrappedNumber),
                label: entry.name
            )
        }

        context.completeRequest()
    }
}

extension CallDirectoryHandler: CXCallDirectoryExtensionContextDelegate {
    func requestFailed(for extensionContext: CXCallDirectoryExtensionContext, withError error: Error) {
        // iOS logs this itself; nothing else to surface from inside the extension.
    }
}
