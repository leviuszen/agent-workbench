# Sample Cache Policy Proposal

This fictional service caches product summaries for five minutes to reduce repeated database reads.

## Proposed Behavior

- Read requests return the cached summary when one exists.
- Write requests invalidate the product cache entry after the database transaction succeeds.
- A cache miss reads from the database and writes a new cache entry.
- If the cache is unavailable, reads fall back to the database.

## Assumptions

- Product writes occur only through this service.
- Cache invalidation reaches every application instance before the next read.
- Five minutes of staleness is acceptable for non-critical fields.
- Database fallback capacity is sufficient during a cache outage.

## Open Questions

- How should bulk imports invalidate entries?
- Which fields are critical enough to bypass the cache?
- What evidence would establish acceptable database fallback capacity?
