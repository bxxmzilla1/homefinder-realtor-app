import SwiftUI

struct FiltersView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var draft: SearchFilters
    let onApply: (SearchFilters) -> Void

    init(filters: SearchFilters, onApply: @escaping (SearchFilters) -> Void) {
        _draft = State(initialValue: filters)
        self.onApply = onApply
    }

    var body: some View {
        NavigationView {
            Form {
                Section("Listing type") {
                    Picker("Transaction", selection: $draft.transaction) {
                        ForEach(SearchFilters.Transaction.allCases) { Text($0.label).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    .onChange(of: draft.transaction) { _ in
                        draft.minPrice = nil
                        draft.maxPrice = nil
                    }

                    Picker("Property type", selection: $draft.propertyClass) {
                        ForEach(SearchFilters.PropertyClass.allCases) { Text($0.label).tag($0) }
                    }
                }

                Section(draft.transaction == .sale ? "Price" : "Monthly rent") {
                    Picker("Minimum", selection: $draft.minPrice) {
                        Text("No min").tag(Int?.none)
                        ForEach(draft.priceOptions, id: \.self) { Text(Format.price(Double($0))).tag(Int?.some($0)) }
                    }
                    Picker("Maximum", selection: $draft.maxPrice) {
                        Text("No max").tag(Int?.none)
                        ForEach(draft.priceOptions, id: \.self) { Text(Format.price(Double($0))).tag(Int?.some($0)) }
                    }
                }

                Section("Rooms") {
                    Picker("Bedrooms", selection: $draft.minBeds) {
                        Text("Any").tag(0)
                        ForEach(1...5, id: \.self) { Text("\($0)+").tag($0) }
                    }
                    Picker("Bathrooms", selection: $draft.minBaths) {
                        Text("Any").tag(0)
                        ForEach(1...5, id: \.self) { Text("\($0)+").tag($0) }
                    }
                }

                Section("Keywords") {
                    TextField("e.g. pool, garage, waterfront", text: $draft.keywords)
                        .disableAutocorrection(true)
                        .textInputAutocapitalization(.never)
                }

                Section("Sort by") {
                    Picker("Sort", selection: $draft.sort) {
                        ForEach(SearchFilters.Sort.allCases) { Text($0.label).tag($0) }
                    }
                }

                Section {
                    Button("Reset filters", role: .destructive) {
                        draft = SearchFilters(transaction: draft.transaction)
                    }
                }
            }
            .navigationTitle("Filters")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Apply") {
                        onApply(draft)
                        dismiss()
                    }
                    .font(.body.bold())
                }
            }
        }
        .navigationViewStyle(.stack)
    }
}
