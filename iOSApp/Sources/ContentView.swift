import SwiftUI

enum ActiveSheet: Identifiable {
    case detail(Listing)
    case filters
    case settings

    var id: String {
        switch self {
        case .detail(let listing): return "detail-\(listing.id)"
        case .filters: return "filters"
        case .settings: return "settings"
        }
    }
}

struct ContentView: View {
    @EnvironmentObject private var settings: AppSettings
    @StateObject private var vm = ListingsViewModel()
    @StateObject private var location = LocationProvider()
    @State private var showList = false
    @State private var sheet: ActiveSheet?
    @State private var searchText = ""
    @FocusState private var searchFocused: Bool

    var body: some View {
        ZStack(alignment: .top) {
            ListingsMapView(
                listings: vm.listings,
                focus: vm.focus,
                onRegionChange: { vm.regionChanged($0) },
                onSelect: { sheet = .detail($0) }
            )
            .ignoresSafeArea()

            if showList {
                ListingsListView(
                    listings: vm.listings,
                    total: vm.totalInArea,
                    isLoading: vm.isLoading,
                    onSelect: { sheet = .detail($0) },
                    onRefresh: { vm.reload() }
                )
                .padding(.top, 118)
                .background(Color(.systemGroupedBackground).ignoresSafeArea())
                .transition(.move(edge: .bottom))
            }

            VStack(spacing: 8) {
                searchBar
                if searchFocused && !vm.suggestions.isEmpty {
                    suggestionsList
                } else {
                    statusPill
                }
                Spacer()
                bottomBar
            }
            .padding(.horizontal, 12)
            .padding(.bottom, 8)
        }
        .animation(.easeInOut(duration: 0.25), value: showList)
        .sheet(item: $sheet) { item in
            switch item {
            case .detail(let listing):
                ListingDetailView(listing: listing)
            case .filters:
                FiltersView(filters: vm.filters) { vm.filters = $0 }
            case .settings:
                SettingsView(onSaved: { vm.reload() })
                    .environmentObject(settings)
            }
        }
        .onAppear {
            location.onLocation = { vm.move(to: $0, span: 0.08) }
            if !settings.isConfigured { sheet = .settings }
        }
        .alert(
            "Location unavailable",
            isPresented: Binding(
                get: { location.deniedMessage != nil },
                set: { if !$0 { location.deniedMessage = nil } }
            ),
            actions: { Button("OK", role: .cancel) {} },
            message: { Text(location.deniedMessage ?? "") }
        )
    }

    private var searchBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass").foregroundColor(.secondary)
            TextField("City, neighbourhood or address", text: $searchText)
                .focused($searchFocused)
                .textInputAutocapitalization(.words)
                .disableAutocorrection(true)
                .submitLabel(.search)
                .onSubmit {
                    if let first = vm.suggestions.first { choose(first) }
                }
                .onChange(of: searchText) { vm.updateSuggestions(for: $0) }
            if !searchText.isEmpty {
                Button {
                    searchText = ""
                    vm.suggestions = []
                } label: {
                    Image(systemName: "xmark.circle.fill").foregroundColor(.secondary)
                }
            }
        }
        .padding(.horizontal, 12)
        .frame(height: 46)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .shadow(color: .black.opacity(0.15), radius: 6, y: 2)
    }

    private var suggestionsList: some View {
        VStack(spacing: 0) {
            ForEach(vm.suggestions.prefix(6)) { suggestion in
                Button {
                    choose(suggestion)
                } label: {
                    HStack {
                        Image(systemName: "mappin.circle.fill").foregroundColor(Color(Brand.red))
                        VStack(alignment: .leading, spacing: 2) {
                            Text(suggestion.name).foregroundColor(.primary)
                            Text(suggestion.subtitle).font(.caption).foregroundColor(.secondary)
                        }
                        Spacer()
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .contentShape(Rectangle())
                }
                Divider().padding(.leading, 40)
            }
        }
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .shadow(color: .black.opacity(0.15), radius: 6, y: 2)
    }

    @ViewBuilder
    private var statusPill: some View {
        HStack(spacing: 6) {
            if vm.isLoading {
                ProgressView().scaleEffect(0.8)
                Text("Loading listings…")
            } else if let error = vm.errorMessage {
                Image(systemName: "exclamationmark.triangle.fill").foregroundColor(.orange)
                Text(error).lineLimit(2)
                Button("Retry") { vm.reload() }.font(.footnote.bold())
            } else if vm.totalInArea > vm.listings.count {
                Text("Showing \(Format.count(vm.listings.count)) of \(Format.count(vm.totalInArea)) · zoom in for more")
            } else {
                Text("\(Format.count(vm.totalInArea)) listings in this area")
            }
        }
        .font(.footnote)
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .background(.regularMaterial, in: Capsule())
        .shadow(color: .black.opacity(0.1), radius: 4, y: 1)
    }

    private var bottomBar: some View {
        HStack(spacing: 10) {
            barButton(
                icon: "slider.horizontal.3",
                label: vm.filters.activeCount > 0 ? "Filters (\(vm.filters.activeCount))" : "Filters"
            ) { sheet = .filters }

            Picker("", selection: Binding(
                get: { vm.filters.listingType },
                set: { newValue in
                    var updated = vm.filters
                    updated.listingType = newValue
                    updated.minPrice = nil
                    updated.maxPrice = nil
                    vm.filters = updated
                }
            )) {
                ForEach(SearchFilters.ListingType.allCases) { Text($0.label).tag($0) }
            }
            .pickerStyle(.segmented)
            .frame(maxWidth: 180)

            barButton(icon: showList ? "map" : "list.bullet", label: showList ? "Map" : "List") {
                searchFocused = false
                showList.toggle()
            }

            if !showList {
                circleButton("location.fill") { location.requestLocation() }
            }
            circleButton("gearshape.fill") { sheet = .settings }
        }
        .padding(8)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .shadow(color: .black.opacity(0.15), radius: 6, y: 2)
    }

    private func barButton(icon: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(label, systemImage: icon)
                .font(.footnote.bold())
                .lineLimit(1)
                .padding(.horizontal, 10)
                .frame(height: 34)
                .background(Color(Brand.red), in: Capsule())
                .foregroundColor(.white)
        }
    }

    private func circleButton(_ icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .semibold))
                .frame(width: 34, height: 34)
                .background(Color(.systemBackground), in: Circle())
                .foregroundColor(Color(Brand.red))
        }
    }

    private func choose(_ suggestion: LocationSuggestion) {
        searchText = suggestion.name
        searchFocused = false
        showList = false
        vm.select(suggestion)
    }
}
