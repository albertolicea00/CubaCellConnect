import SwiftUI

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
