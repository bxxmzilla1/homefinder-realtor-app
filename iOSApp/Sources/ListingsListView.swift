import SwiftUI

struct ListingsListView: View {
    let listings: [Listing]
    let total: Int
    let isLoading: Bool
    let onSelect: (Listing) -> Void
    let onRefresh: () -> Void

    var body: some View {
        if listings.isEmpty && !isLoading {
            VStack(spacing: 12) {
                Image(systemName: "house.circle").font(.system(size: 48)).foregroundColor(.secondary)
                Text("No listings in this map area").font(.headline)
                Text("Move or zoom out the map, or loosen your filters.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(32)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            List {
                Section(footer: footer) {
                    ForEach(listings) { listing in
                        Button { onSelect(listing) } label: { ListingRow(listing: listing) }
                            .buttonStyle(.plain)
                    }
                }
            }
            .listStyle(.insetGrouped)
            .refreshable { onRefresh() }
            .padding(.bottom, 64)
        }
    }

    private var footer: some View {
        Group {
            if total > listings.count {
                Text("Showing \(Format.count(listings.count)) of \(Format.count(total)). Zoom the map in to narrow the area.")
            } else {
                Text("\(Format.count(total)) listings in this map area.")
            }
        }
    }
}

struct ListingRow: View {
    let listing: Listing

    var body: some View {
        HStack(spacing: 12) {
            RemoteImage(url: listing.photos.first)
                .frame(width: 110, height: 82)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

            VStack(alignment: .leading, spacing: 4) {
                Text(Format.price(listing.price, lease: listing.isLease))
                    .font(.headline)
                Text(listing.addressFull ?? "Address unavailable")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
                HStack(spacing: 10) {
                    if let beds = listing.bedsText { Label(beds, systemImage: "bed.double.fill") }
                    if let baths = listing.baths { Label(Format.number(baths), systemImage: "shower.fill") }
                    if let type = listing.propertyType { Text(type).lineLimit(1) }
                }
                .font(.caption)
                .foregroundColor(.secondary)
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
    }
}

struct RemoteImage: View {
    let url: URL?

    var body: some View {
        ZStack {
            Color(.secondarySystemFill)
            if let url {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image.resizable().scaledToFill()
                    case .failure:
                        placeholder
                    default:
                        ProgressView()
                    }
                }
            } else {
                placeholder
            }
        }
        .clipped()
    }

    private var placeholder: some View {
        Image(systemName: "house.fill")
            .font(.title2)
            .foregroundColor(.secondary)
    }
}
