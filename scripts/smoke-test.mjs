import "dotenv/config";
import { searchListings, getListing } from "../src/repliers/client.js";

const search = await searchListings({ resultsPerPage: 3, status: "A" });
console.log("paging", search.paging);
for (const r of search.results) {
  console.log(r.mls_number, r.price, r.beds, r.baths, r.address_full);
}

const first = search.results[0];
if (first) {
  const detail = await getListing(first.mls_number, first.board_id ? { boardId: first.board_id } : {});
  console.log("detail", detail.mls_number, detail.address_full, detail.photo_url);
}
