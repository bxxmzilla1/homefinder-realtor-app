const IMAGE_CDN = process.env.REPLIERS_IMAGE_CDN || "https://cdn.repliers.io";

function toNumber(value) {
  const n = Number(value);
  return value === undefined || value === null || value === "" || Number.isNaN(n)
    ? null
    : n;
}

function imageUrl(path) {
  if (!path) return null;
  return /^https?:\/\//.test(path) ? path : `${IMAGE_CDN}/${path.replace(/^\//, "")}`;
}

function formatAddress(address = {}) {
  const unit =
    address.unitNumber && address.unitNumber !== "0" ? `${address.unitNumber} - ` : "";
  const street = [
    address.streetNumber,
    address.streetName,
    address.streetSuffix,
    address.streetDirection,
  ]
    .filter(Boolean)
    .join(" ");
  const locality = [address.city, address.state, address.zip].filter(Boolean).join(", ");
  return {
    street: `${unit}${street}`.trim(),
    full: [`${unit}${street}`.trim(), locality].filter(Boolean).join(", "),
  };
}

export function normalizeListing(listing = {}) {
  const address = listing.address ?? {};
  const details = listing.details ?? {};
  const agent = listing.agents?.[0];
  const formatted = formatAddress(address);
  const images = (listing.images ?? []).map(imageUrl).filter(Boolean);

  return {
    mls_number: listing.mlsNumber,
    board_id: listing.boardId ?? null,
    status: listing.status,
    last_status: listing.lastStatus,
    transaction_type: listing.type,
    class: listing.class,
    price: toNumber(listing.listPrice),
    original_price: toNumber(listing.originalPrice),
    sold_price: toNumber(listing.soldPrice) || null,
    list_date: listing.listDate ?? null,
    address_street: formatted.street,
    address_full: formatted.full,
    city: address.city ?? null,
    area: address.area ?? null,
    neighborhood: address.neighborhood ?? null,
    postal_code: address.zip ?? null,
    province: address.state ?? null,
    lat: toNumber(listing.map?.latitude),
    lon: toNumber(listing.map?.longitude),
    property_type: details.propertyType ?? null,
    style: details.style ?? null,
    beds: toNumber(details.numBedrooms),
    beds_plus: toNumber(details.numBedroomsPlus),
    baths: toNumber(details.numBathrooms),
    sqft: details.sqft ?? null,
    description: details.description ?? null,
    photo_url: images[0] ?? null,
    photo_urls: images,
    agent_name: agent?.name ?? null,
    agent_brokerage: agent?.brokerage?.name ?? null,
  };
}

export function normalizeSearchResponse(data = {}) {
  return {
    paging: {
      page: data.page,
      page_size: data.pageSize,
      total_pages: data.numPages,
      total_records: data.count,
    },
    results: (data.listings ?? data.similar ?? []).map(normalizeListing),
    ...(data.statistics ? { statistics: data.statistics } : {}),
  };
}
