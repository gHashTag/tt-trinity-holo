# Zenodo DOI Deposit Checklist · tt-trinity-holo

This guide walks through registering a versioned DOI on Zenodo for the
**tt-trinity-holo** repository (L-DPC24 HOLOGRAPHIC v9).

Concept DOI (already registered): `10.5281/zenodo.19227877`

---

## Step 1 — Tag a v0.1.0 release

```bash
git tag -a v0.1.0 -m "Initial release: L-DPC24 HOLOGRAPHIC v9 · 1×2→1×4→octa tile"
git push origin v0.1.0
```

Then create a GitHub Release from the tag via the GitHub UI or `gh release create v0.1.0`.

---

## Step 2 — Link tt-trinity-holo to Zenodo

1. Log in to [https://zenodo.org](https://zenodo.org) with the account that owns `10.5281/zenodo.19227877`.
2. Go to **Account → GitHub**.
3. Find `gHashTag/tt-trinity-holo` in the repository list and **toggle it ON**.
4. Ensure the Zenodo webhook is visible under the repo's GitHub Settings → Webhooks.

---

## Step 3 — Trigger the release → auto-deposit

Once the repo is linked, creating a GitHub Release automatically triggers a Zenodo deposit:

- Zenodo captures the release source archive.
- A **version-specific DOI** is minted (e.g., `10.5281/zenodo.XXXXXXX`).
- It is automatically linked under the concept DOI `10.5281/zenodo.19227877`.
- Optionally add the deposit to community `trinity-s3ai`:
  - In the Zenodo deposit form, search for community `trinity-s3ai` and submit for review.

---

## Step 4 — Verify DOI HEAD 200 OK

```bash
curl -sI "https://doi.org/10.5281/zenodo.19227877" | head -5
# Expected: HTTP/2 200 (or 302 redirect resolving to 200)
```

Repeat for the version-specific DOI once minted.

---

## Step 5 — Update CITATION.cff with the version-specific DOI

After the deposit, add the version DOI to `CITATION.cff`:

```yaml
identifiers:
  - type: doi
    value: 10.5281/zenodo.19227877
    description: "Concept DOI for the Trinity / Flos Aureus / HOLOGRAPHIC v9 line"
  - type: doi
    value: 10.5281/zenodo.XXXXXXX        # ← replace with actual version DOI
    description: "Version DOI for tt-trinity-holo v0.1.0"
```

Commit the update:

```bash
git add CITATION.cff
git commit -m "chore: add version-specific Zenodo DOI for v0.1.0"
git push
```

---

## Anchor

φ²+φ⁻²=3 · γ=φ⁻³ · C=φ⁻¹ · G=π³γ²/φ
