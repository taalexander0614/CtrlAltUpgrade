# Phishing Triage Score (n8n)

Rule-based scoring for emails users report as phishing. Every point the rubric adds comes with a plain-language reason, so a technician can see *why* a report scored the way it did and make the call quickly. Written up in [A phishing triage score that explains itself](https://www.ctrlaltupgrade.com/blog/phishing-triage-score/).

This is a sanitized copy of the two Code nodes from a production workflow. Organization names, domains and people are replaced with values in a CONFIG block. The surrounding workflow (mailbox intake, chat cards, remediation) is specific to my environment and isn't included.

| File | n8n node | What it does |
|---|---|---|
| `sender-history-lookup.js` | Code, before the history query | Works out whose history to look up: the real sender address (not the display name), or the outside sharer for Drive/DocuSign/etc. shares. Freemail by full address, everyone else by domain. |
| `phishing-triage-rubric.js` | Code, after the history query | Scores the report 0–100 and returns a band, a suggestion, the top reasons, tips for the reviewer, and the sender-check results. |

## What it checks
- **Sender authentication**, using only the verdicts Microsoft stamped on the message (its own Authentication-Results block), since lower headers can be forged. Spoofing your own domain is the heaviest signal.
- **Look-alike domains**: punycode decoded, confusable characters folded (Cyrillic "а", "rn" for "m"), and edit distance against your name.
- **Where replies and links go**: personal reply-to addresses, free hosting and form builders, shorteners, raw IPs, unrelated link domains.
- **Lures**: payroll/HR, password and sign-in, gift cards, invoices, job offers, fake voicemail, documents to sign, urgency, document-style PDFs.
- **Filter-evasion signs**: almost no readable text, random-code subjects.
- **History**: earlier verdicts for the same sender nudge the score up or down (6-month window, never counting the same message).

Bands: 60+ likely phishing · 35+ suspicious · marketing/bulk · 15+ low risk · below 15 likely legitimate.

## Setup
1. Edit the CONFIG block at the top of `phishing-triage-rubric.js` (`OUR_DOMAIN`, `ORG_NAME`, `IMITATED`, `TRUSTED_DOMAINS`, `LEADERSHIP_RE`) and `OUR_DOMAIN` in `sender-history-lookup.js`.
2. The rubric expects an earlier node named **Restore Reports Summary** (one item with `sender`, `reply_to`, `subject`, `body_excerpt`, `links`, `attachments`, `authentication`, `internet_message_id`, `report_id`) and **Sender History** (past reports with `message_json`, `outcome`, `review_json`, `createdAt`). Rename those references to match your workflow.
3. Links are expected defanged (`hxxps://`, `[.]`), the way most report collectors pass them.
4. Run it in shadow mode against real reports and compare with what a person decides before anyone relies on it.

## License
GPL-3.0, like the rest of this repository.
