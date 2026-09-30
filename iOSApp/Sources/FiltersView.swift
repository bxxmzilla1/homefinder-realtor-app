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
            form
                .navigationTitle("Filters")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar { toolbarContent }
        }
        .navigationViewStyle(.stack)
    }

    private var form: some View {
        Form {
            listingTypeSection
            priceSection
            roomsSection
            keywordsSection
            sortSection
            Section {
                Button("Reset filters", role: .destructive) {
                    draft = SearchFilters(listingType: draft.listingType)
                }
            }
        }
    }

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
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

    private var listingTypeSection: some View {
        Section(header: Text("Listing type")) {
            Picker("Listing type", selection: $draft.listingType) {
                ForEach(SearchFilters.ListingType.allCases) { option in
                    Text(option.label).tag(option)
                }
            }
            .pickerStyle(.segmented)
            .onChange(of: draft.listingType) { _ in
                draft.minPrice = nil
                draft.maxPrice = nil
            }

            Picker("Property type", selection: $draft.propertyClass) {
                ForEach(SearchFilters.PropertyClass.allCases) { option in
                    Text(option.label).tag(option)
                }
            }
        }
    }

    private var priceSection: some View {
        Section(header: Text(draft.listingType == .sale ? "Price" : "Monthly rent")) {
            PricePicker(title: "Minimum", noneLabel: "No min", options: draft.priceOptions, selection: $draft.minPrice)
            PricePicker(title: "Maximum", noneLabel: "No max", options: draft.priceOptions, selection: $draft.maxPrice)
        }
    }

    private var roomsSection: some View {
        Section(header: Text("Rooms")) {
            RoomPicker(title: "Bedrooms", selection: $draft.minBeds)
            RoomPicker(title: "Bathrooms", selection: $draft.minBaths)
        }
    }

    private var keywordsSection: some View {
        Section(header: Text("Keywords")) {
            TextField("e.g. pool, garage, waterfront", text: $draft.keywords)
                .disableAutocorrection(true)
                .textInputAutocapitalization(.never)
        }
    }

    private var sortSection: some View {
        Section(header: Text("Sort by")) {
            Picker("Sort", selection: $draft.sort) {
                ForEach(SearchFilters.Sort.allCases) { option in
                    Text(option.label).tag(option)
                }
            }
        }
    }
}

private struct PricePicker: View {
    let title: String
    let noneLabel: String
    let options: [Int]
    @Binding var selection: Int?

    var body: some View {
        Picker(title, selection: $selection) {
            Text(noneLabel).tag(Int?.none)
            ForEach(options, id: \.self) { value in
                Text(Format.price(Double(value))).tag(Int?.some(value))
            }
        }
    }
}

private struct RoomPicker: View {
    let title: String
    @Binding var selection: Int

    var body: some View {
        Picker(title, selection: $selection) {
            Text("Any").tag(0)
            ForEach(1...5, id: \.self) { value in
                Text("\(value)+").tag(value)
            }
        }
    }
}
