// ===== Phishing triage rubric (n8n Code node) =====
// Rule-based scoring for user-reported emails: every point comes with a plain-language reason.
// Write-up: https://www.ctrlaltupgrade.com/blog/phishing-triage-score/
// Sanitized copy of a production rubric: organization names, domains and people replaced with CONFIG values.
// License: GPL-3.0 (see repository LICENSE).

// ===== CONFIG: edit for your organization =====
const OUR_DOMAIN = 'example.org';                        // your mail domain (subdomains count as yours)
const ORG_NAME = 'example';                              // a distinctive word from your name, lowercase (used for "named like us" checks)
// Vendors you really use whose names/links would otherwise look odd.
const TRUSTED_DOMAINS = ['knowbe4.com'];
// Other organizations that share part of your name and that you really deal with (no look-alike points). Verify before adding.
const NAME_PARTNERS = [];
// Strings an attacker would imitate. The registrable name (dots/hyphens removed, look-alike characters folded)
// within 2 edits of one of these, or containing one, scores as a look-alike.
const IMITATED = ['example', 'exampleschools', 'examplek12'];
// Words that mean "leadership or an internal department" in your organization. Matched in outside mail only.
const LEADERSHIP_RE = /superintendent|human resources|payroll (department|office)|help ?desk|it department|technology department/;
// Suffixes treated as one unit when finding the registrable domain.
const MULTI_PART_SUFFIXES = ['k12.nc.us','co.uk','com.au','org.uk','gov.uk','ac.uk'];
// ===== end CONFIG =====

const FREEMAIL = ['gmail.com','yahoo.com','outlook.com','hotmail.com','live.com','aol.com','icloud.com','me.com','proton.me','protonmail.com','gmx.com','mail.com','zoho.com','yandex.com'];
const FILE_SHARE_SENDERS = ['drive-shares-dm-noreply@google.com','drive-shares-noreply@google.com','comments-noreply@docs.google.com','no-reply@sharepointonline.com','no-reply@onedrive.com','dse@docusign.net','dse_na2@docusign.net','dse_na3@docusign.net','dse_na4@docusign.net','no-reply@dropbox.com','noreply@box.com','no-reply@notify.box.com'];
const BENIGN_LINK_DOMAINS = ['gstatic.com','googleusercontent.com','googleapis.com','egress.com','mimecast.com','safelinks.protection.outlook.com','aka.ms','microsoft.com','office.com','w3.org'];
const SHORTENERS = ['bit.ly','tinyurl.com','t.co','rebrand.ly','is.gd','cutt.ly','ow.ly','buff.ly','shorturl.at','rb.gy','t.ly','tiny.cc','s.id'];
const FREE_HOSTING = ['sites.google.com','forms.gle','firebaseapp.com','web.app','pages.dev','workers.dev','glitch.me','ngrok.io','ngrok-free.app','weebly.com','wixsite.com','blogspot.com','github.io','netlify.app','vercel.app','herokuapp.com','000webhostapp.com','godaddysites.com','square.site','canva.site','jotform.com','typeform.com','formstack.com','ipfs.io','r2.dev','azurewebsites.net','blob.core.windows.net','storage.googleapis.com'];
const RISKY_TLDS = ['xyz','top','click','link','info','co','buzz','shop','online','site','live','icu','rest','cfd','sbs','cyou','monster','quest','support','zip','mov'];
const RISKY_ATTACH = /\.(html?|shtml|svg|zip|rar|7z|iso|img|vhdx?|exe|msi|js|jse|vbs|wsf|lnk|one|hta|scr|bat|cmd|ps1|jar|docm|xlsm|pptm|dotm|xlam)\b/i;
// Characters commonly used to imitate Latin letters (Cyrillic, Greek, digits) -> what they imitate.
const CONFUSABLE = { 'а':'a','е':'e','о':'o','р':'p','с':'c','у':'y','х':'x','і':'i','ј':'j','ԁ':'d','ɡ':'g','һ':'h','ո':'n','ѕ':'s','ԛ':'q','ԝ':'w','ο':'o','ι':'i','ν':'v','κ':'k','τ':'t','α':'a','ε':'e','ρ':'p','0':'o','1':'l','3':'e','5':'s','|':'l' };

const text = v => (v == null ? '' : String(v)).normalize('NFKC');
const lower = v => text(v).toLowerCase();

// RFC 3492 punycode label decoding (xn--...), so look-alike checks see the real characters.
function punyLabel(label) {
  if (!label.startsWith('xn--')) return label;
  try {
    const input = label.slice(4); const base = 36, tMin = 1, tMax = 26, skew = 38, damp = 700;
    let n = 128, i = 0, bias = 72, out = [];
    const d = input.lastIndexOf('-');
    if (d > 0) out = Array.from(input.slice(0, d));
    const digit = c => { const x = c.charCodeAt(0); return x - 48 < 10 ? x - 22 : x - 65 < 26 ? x - 65 : x - 97 < 26 ? x - 97 : base; };
    const adapt = (delta, num, first) => { delta = first ? Math.floor(delta / damp) : delta >> 1; delta += Math.floor(delta / num); let k = 0; for (; delta > ((base - tMin) * tMax) >> 1; k += base) delta = Math.floor(delta / (base - tMin)); return Math.floor(k + (base - tMin + 1) * delta / (delta + skew)); };
    for (let p = d > 0 ? d + 1 : 0; p < input.length;) {
      const oldi = i;
      for (let w = 1, k = base; ; k += base) {
        const dg = digit(input[p++]); if (dg >= base) return label;
        i += dg * w; const t = k <= bias ? tMin : k >= bias + tMax ? tMax : k - bias;
        if (dg < t) break; w *= base - t;
      }
      bias = adapt(i - oldi, out.length + 1, oldi === 0); n += Math.floor(i / (out.length + 1)); i %= out.length + 1;
      out.splice(i++, 0, String.fromCodePoint(n));
    }
    return out.join('');
  } catch (e) { return label; }
}
const unicodeDomain = d => lower(d).replace(/\[\.\]/g, '.').split('.').map(punyLabel).join('.');
const baseDomain = d => {
  d = unicodeDomain(d).replace(/[^\p{L}\p{N}.-]/gu, '').replace(/^\.+|\.+$/g, '');
  if (!d) return '';
  if (d === OUR_DOMAIN || d.endsWith('.' + OUR_DOMAIN)) return OUR_DOMAIN;
  const parts = d.split('.');
  for (const s of MULTI_PART_SUFFIXES) if (d.endsWith('.' + s)) return parts.slice(-(s.split('.').length + 1)).join('.');
  return parts.slice(-2).join('.');
};
// The real address: the one inside ‹ › / < > if present (the collector turns < > into ‹ ›), otherwise the LAST
// address in the string, so a display name like "helpdesk@example.org" can't stand in for the sender.
const ADDR = /[\p{L}\p{N}._%+-]+@([\p{L}\p{N}-]+(?:\.[\p{L}\p{N}-]+)+)/gu;
const emailOf = v => {
  const s = lower(v);
  const b = s.match(/[‹<]\s*([^‹›<>\s]+@[^‹›<>\s]+)\s*[›>]/);
  const all = [...(b ? b[1] : s).matchAll(ADDR)].map(m => m[0]);
  return all.length ? all[all.length - 1] : '';
};
const domainOf = v => { const e = emailOf(v); return e ? unicodeDomain(e.split('@')[1]) : ''; };
const isOurs = d => d === OUR_DOMAIN || d.endsWith('.' + OUR_DOMAIN);
const inList = (d, list) => list.some(x => d === x || d.endsWith('.' + x));
const plural = (n, w) => n + ' ' + w + (n === 1 ? '' : 's');
const skeleton = s => Array.from(lower(s)).map(c => CONFUSABLE[c] ?? c).join('').replace(/rn/g, 'm').replace(/vv/g, 'w').replace(/[^a-z0-9]/g, '');
const editDistance = (a, b) => {
  const dp = Array.from({ length: a.length + 1 }, (_, i) => [i]);
  for (let j = 1; j <= b.length; j++) dp[0][j] = j;
  for (let i = 1; i <= a.length; i++) for (let j = 1; j <= b.length; j++)
    dp[i][j] = Math.min(dp[i - 1][j] + 1, dp[i][j - 1] + 1, dp[i - 1][j - 1] + (a[i - 1] === b[j - 1] ? 0 : 1));
  return dp[a.length][b.length];
};
// 'strong' = imitates us; 'samename' = another organization sharing our name; '' = neither.
const lookalikeKind = d => {
  if (!d || isOurs(d) || inList(d, TRUSTED_DOMAINS) || inList(d, NAME_PARTNERS)) return '';
  const full = unicodeDomain(d);
  const name = skeleton(full.replace(/\.[a-z\p{L}]{2,}$/u, ''));
  const words = full.replace(/[.-]/g, ' ');
  if (IMITATED.some(t => name.includes(t) || (name.length >= t.length - 2 && editDistance(name, t) <= 2))) return 'strong';
  if (/[^\x00-\x7f]/.test(full) && skeleton(full).includes(ORG_NAME)) return 'strong';
  if (name.includes(ORG_NAME)) return 'samename';
  return '';
};

function triage(r, history) {
  const factors = [];
  const tips = [];
  const add = (points, reason, tip) => { factors.push({ points, reason }); if (tip) tips.push(tip); };

  const sender = emailOf(r.sender);
  const senderDomain = domainOf(r.sender);
  const senderBase = baseDomain(senderDomain);
  const replyRaw = lower(r.reply_to);
  const replyTo = replyRaw.includes('not supplied') ? '' : emailOf(r.reply_to);
  const replyDomain = replyTo ? unicodeDomain(replyTo.split('@')[1]) : '';
  const replyBase = baseDomain(replyDomain);
  const subject = text(r.subject);
  const body = text(r.body_excerpt);
  const content = (subject + '\n' + body).toLowerCase();
  const auth = lower(r.authentication);
  const linksRaw = text(r.links);
  const attachments = text(r.attachments);
  const hasAttachments = attachments && !/none found|not supplied/i.test(attachments);

  // ---- Links: collect domains from defanged URLs in links + body
  const linkDomains = {};
  for (const m of (linksRaw + '\n' + body).matchAll(/h(?:xx|tt)ps?:\/\/([^\/\s?#‹›<>"']+)/gi)) {
    const host = lower(m[1]).replace(/\[\.\]/g, '.').replace(/:\d+$/, '').replace(/^.*@/, '');
    if (host) linkDomains[host] = (linkDomains[host] || 0) + 1;
  }
  const hosts = Object.keys(linkDomains);
  const meaningfulHosts = hosts.filter(h => !inList(h, BENIGN_LINK_DOMAINS));

  // ---- Sender authentication: Microsoft's own verdicts only. Microsoft adds its Authentication-Results at the
  // top, and it always ends with "compauth=<result> reason=<NNN>". Anything after that comes from headers lower
  // down, which the sender can forge, so it is ignored. (No compauth: up to the next header's "; spf=".)
  const ca = auth.match(/compauth=\w+ reason=\d+/);
  const s1 = auth.search(/\bspf=/), s2 = s1 < 0 ? -1 : auth.slice(s1 + 4).search(/;\s*spf=/);
  const msBlock = ca ? auth.slice(0, ca.index + ca[0].length) : (s1 < 0 ? auth : auth.slice(0, s2 < 0 ? undefined : s1 + 4 + s2));
  const first = (re) => { const m = msBlock.match(re); return m ? m[1] : ''; };
  const spf = first(/spf=(\w+)/), dkim = first(/dkim=(\w+)/), dmarc = first(/dmarc=(\w+)/), compauth = first(/compauth=(\w+)/);
  const headerFrom = first(/header\.from=([^\s;]+)/);
  // A trusted forwarder/gateway: DMARC failed but Microsoft's composite verdict still passed (e.g. reason 130,
  // a trusted ARC chain). Lower, forgeable headers are no longer consulted.
  const gatewayRewrite = dmarc === 'fail' && compauth === 'pass';
  const claimsOurs = isOurs(senderDomain) || isOurs(headerFrom);
  const internal = claimsOurs && !spf && (dmarc === 'none' || !dmarc) && /protection\.outlook\.com|prod\.outlook\.com/.test(lower(r.internet_message_id) + auth) && !/fail/.test(msBlock);
  const external = !internal;

  if (claimsOurs && (dmarc === 'fail' || compauth === 'fail')) {
    add(35, 'Pretends to be from a ' + OUR_DOMAIN + ' address, but Microsoft says it was not sent by us (spoofed)', 'Spoofing our own domain is a strong phishing sign; treat as Malicious unless it is a known simulation.');
  } else if (dmarc === 'fail' && gatewayRewrite) {
    add(5, 'Sender checks failed only after passing through a mail security gateway (common for forwarded/marketing mail)');
  } else if (dmarc === 'fail' || compauth === 'fail') {
    add(20, 'Failed Microsoft\'s sender check (DMARC/compauth) — may not be from who it claims');
  } else if (internal) {
    add(-10, 'Sent from inside the organization');
  } else if (dmarc === 'pass' && (dkim === 'pass' || spf === 'pass')) {
    add(-5, 'Passed sender checks for ' + (headerFrom || senderDomain) + ' (this proves where it came from, not that it is safe)');
  }

  // ---- Who it's really from
  const trustedSender = inList(senderDomain, TRUSTED_DOMAINS);
  const isFileShare = FILE_SHARE_SENDERS.includes(sender);
  const lookDomains = [senderDomain, replyDomain, ...meaningfulHosts.map(unicodeDomain)];
  const strongHit = lookDomains.find(d => lookalikeKind(d) === 'strong');
  const sameNameHit = strongHit ? '' : lookDomains.find(d => lookalikeKind(d) === 'samename');
  if (strongHit) {
    add(25, 'Uses a look-alike of our name: ' + strongHit, 'Look-alike domains are almost never legitimate.');
  } else if (sameNameHit) {
    add(10, 'Shares part of our name but is not one of our addresses: ' + sameNameHit, 'Other organizations may share our name. Check whether this one is expected.');
  }
  if (lookDomains.some(d => d && /[^\x00-\x7f]/.test(d))) {
    add(10, 'Uses international characters in a web address (these can imitate normal letters)');
  }
  const lookalike = d => !!lookalikeKind(d);
  if (isFileShare && replyDomain && !isOurs(replyDomain)) {
    add(15, 'A file was shared by someone outside the organization (' + replyTo + ') — a common way to slip past filters', 'Do not open the shared file. Ask: do we actually work with ' + replyBase + '?');
  } else if (replyDomain && replyBase !== senderBase && !lookalike(replyDomain)) {
    if (inList(replyDomain, FREEMAIL)) add(20, 'Replies go to a personal email account (' + replyDomain + ')', 'Businesses rarely ask you to reply to a personal Gmail/Yahoo address.');
    else add(10, 'Replies go to a different organization (' + replyBase + ') than the sender (' + senderBase + ')', 'Check whether ' + replyBase + ' is related to ' + senderBase + ' (vendors often use a parent company).');
  }
  if (!isFileShare && inList(senderDomain, FREEMAIL)) add(10, 'Sent from a personal email account (' + senderDomain + ')');
  const tld = senderBase.split('.').pop();
  if (external && RISKY_TLDS.includes(tld) && !trustedSender) add(10, 'Sender\'s domain ends in .' + tld + ', common for throwaway sites');
  // Content-only signal: worded so it does not count as an "outside sender" signal for the combination bonus.
  if (external && LEADERSHIP_RE.test(content)) {
    add(20, 'Mentions leadership or internal departments, but is not from one of our addresses', 'Real requests from leadership come from @' + OUR_DOMAIN + ', not other services.');
  }

  // ---- What it asks for (each lure counted once)
  const lures = [];
  const lure = (re, pts, label) => { if (re.test(content)) { lures.push(label); add(pts, label); } };
  lure(/compensation|salary|payroll|bonus|\bpay (raise|increase|adjustment|change)|direct deposit|\bw-?2\b|benefits? (enrollment|update)|staff adjustments?/, 15, 'Pay/HR lure (compensation, payroll, direct deposit…)');
  lure(/password|verify your (account|identity|email|mailbox)|mailbox (is )?full|storage (is )?full|re-?activate|account (will be |has been )?(suspended|disabled|deactivated|locked|closed)|\bmfa\b|multi-?factor|sign[- ]in (activity|attempt)|unusual (sign|login)/, 20, 'Asks about your account, password or sign-in');
  lure(/gift ?cards?/, 25, 'Mentions gift cards (classic scam)');
  lure(/invoice|wire transfer|overdue|remittance|payment (due|request|details)|bank (details|account)/, 10, 'Payment/invoice request');
  lure(/side job|from home|per hour|\/hr\b|part[- ]time|easy money|paid (gig|job|opportunity)|hiring now/, 30, 'Job or easy-money offer (common scam)');
  lure(/voicemail|voice ?message|missed call|call entry|\bcaller:|play[- ]?to[- ]?listen|audio transcript|\bfax\b|secure message|encrypted message/, 15, 'Fake voicemail/fax/secure-message notice');
  lure(/sent (you )?a document|shared an item|document to (approve|review|sign)|review and sign|please sign|e-?sign|docusign/, 10, 'Asks you to open/approve/sign a document');
  lure(/urgent|immediately|asap|within (24|48) hours|final (notice|warning)|action required|expires? (today|soon)|expiring/, 10, 'Pressure to act fast');
  // A PDF "document" from outside: reports, statements, agreements etc.
  if (external && hasAttachments && /\.pdf\b/i.test(attachments) && !trustedSender &&
      /report|statement|document|agreement|contract|proposal|policy|handbook|benefit|payroll|invoice|review|summary|notice|form\b/.test(content + ' ' + lower(attachments))) {
    lures.push('pdf'); add(10, 'A document-style PDF from outside the organization (a common way to deliver a link to a fake sign-in page)', 'Ask the person who reported it whether they expected this document before opening it.');
  }

  // ---- Junk / filter-evasion signs
  const letters = (body.replace(/&#?\w+;/g, '').match(/[a-z]/gi) || []).length;
  if (external && letters < 25) add(10, 'Message has almost no readable text (often used to dodge filters)');
  if (external && (/^[A-Z0-9]{3,}(-[A-Z0-9]{3,}){1,}/.test(subject.trim()) || /\bID:\s*[A-Z0-9]{3,}-[A-Z0-9]{3,}/.test(subject))) add(10, 'Subject is a random-looking code');

  // ---- Links
  if (hosts.some(h => /^\d{1,3}(\.\d{1,3}){3}$/.test(h))) add(20, 'Links point to a raw IP address');
  const shorts = meaningfulHosts.filter(h => inList(h, SHORTENERS));
  if (shorts.length) add(15, 'Uses a link shortener that hides the real destination (' + shorts.join(', ') + ')');
  const freeHosts = meaningfulHosts.filter(h => inList(h, FREE_HOSTING));
  if (freeHosts.length) add(15, 'Links go to free website/form hosting (' + freeHosts.join(', ') + ')', 'Free hosting is popular for fake login pages.');
  const unrelated = meaningfulHosts.filter(h => {
    const b = baseDomain(h);
    return b !== senderBase && b !== replyBase && !isOurs(b) && !inList(h, TRUSTED_DOMAINS) && !inList(h, SHORTENERS) && !inList(h, FREE_HOSTING) && !lookalike(h);
  });
  if (unrelated.length && !isFileShare) add(10, 'Links go to a different site than the sender: ' + [...new Set(unrelated.map(baseDomain))].slice(0, 3).join(', '));

  // ---- Attachments
  const risky = attachments.match(RISKY_ATTACH);
  if (risky) add(30, 'Has a risky attachment type (' + risky[0] + ')', 'Do not open the attachment.');
  if (!hasAttachments && !meaningfulHosts.length && !lures.length) add(-5, 'No links or attachments to click');

  // ---- Combination: an outside/unverified sender plus a lure is the classic phishing pattern.
  // Only sender signals count here (not the content-only leadership rule).
  const outsideSignal = factors.some(f => f.points >= 10 && /outside the organization \(|different organization|personal email|spoofed|look-alike|Failed|throwaway|international characters/.test(f.reason));
  if (outsideSignal && lures.length) add(10, 'Combination of an outside/unverified sender with a lure');

  // ---- Marketing / bulk mail
  const marketing = /unsubscribe|view (this email )?in (your )?browser|newsletter|webinar|manage (your )?(email )?preferences|\bpromo|% off\b|case study|sales/.test(content + ' ' + lower(linksRaw)) || /\/unsubscribe|\/mailings\//.test(lower(linksRaw));

  // ---- History with this sender (or the outside sharer for file shares).
  // Freemail is keyed by the full address (one bad Gmail user says nothing about the rest); other senders by domain.
  // The same message (a reopened case, a second report) is never its own history.
  const keyAddr = isFileShare ? replyTo : sender;
  const keyDom = isFileShare ? replyDomain : senderDomain;
  const byAddress = inList(keyDom, FREEMAIL);
  const histKey = byAddress ? keyAddr : keyDom;
  const now = Date.now();
  const past = (history || []).filter(h => {
    try {
      if (h.internet_message_id && h.internet_message_id === r.internet_message_id) return false;
      if (h.report_id === r.report_id || (r.parent_report_id && (h.report_id === r.parent_report_id || h.root_report_id === r.parent_report_id))) return false;
      const t = Date.parse(h.createdAt || h.registered_at || '');
      if (t && now - t > 180 * 86400000) return false; // older than 6 months: ignore
      const m = JSON.parse(h.message_json || '{}');
      const k = byAddress ? emailOf(isFileShare ? m.reply_to : m.sender) : domainOf(isFileShare ? m.reply_to : m.sender);
      return k && k === histKey;
    } catch { return false; }
  });
  const isTest = h => { try { return /\btest(ing)?\b/i.test(JSON.parse(h.review_json || '{}').reason || ''); } catch { return false; } };
  // "Removal declined" is not a malicious verdict (often declined because it wasn't phishing after all).
  const pastBad = past.filter(h => ['Remediated', 'Removal blocked', 'Removal incomplete'].includes(h.outcome) && !isTest(h)).length;
  const pastGood = past.filter(h => h.outcome === 'Legitimate').length;
  if (histKey && !isOurs(keyDom || '')) {
    if (pastBad && pastGood) add(5, 'Mail from ' + histKey + ' has a mixed history (' + plural(pastBad, 'malicious report') + ', ' + plural(pastGood, 'legitimate report') + ')');
    else if (pastBad) add(pastBad >= 2 ? 20 : 15, 'Mail from ' + histKey + ' was judged malicious before (' + plural(pastBad, 'time') + ')');
    else if (pastGood) add(pastGood >= 2 ? -15 : -10, 'Mail from ' + histKey + ' was reported before and marked legitimate (' + plural(pastGood, 'time') + ')');
  }

  // ---- Score and band
  const raw = factors.reduce((s, f) => s + f.points, 0);
  const score = Math.max(0, Math.min(100, raw));
  let band, label, suggestion;
  if (score >= 60) { band = 'red'; label = '🔴 Likely phishing'; suggestion = 'Malicious'; }
  else if (score >= 35) { band = 'orange'; label = '🟠 Suspicious — look closer'; suggestion = 'Needs Investigation — or Malicious if the checks below confirm it'; }
  else if (marketing) { band = 'yellow'; label = '🟡 Marketing / bulk mail'; suggestion = 'Legitimate (unwanted, but not dangerous)'; }
  else if (score >= 15) { band = 'yellow'; label = '🟡 Low risk — a few flags'; suggestion = 'Probably Legitimate — check the flags below first'; }
  else { band = 'green'; label = '🟢 Likely legitimate'; suggestion = 'Legitimate'; }
  if (!tips.length) tips.push(band === 'green' || band === 'yellow' ? 'If the person who reported it does not recognize the sender, it is fine to mark it Legitimate and let them block/delete it.' : 'Look at where the links really go and who the sender is before deciding.');

  factors.sort((a, b) => b.points - a.points);
  return {
    score, band, label, suggestion, marketing,
    factors, tips: [...new Set(tips)],
    summary: factors.filter(f => f.points > 0).slice(0, 3).map(f => f.reason.split(' (')[0].split(' — ')[0]).join(' · '),
    sender_checks: { spf: spf || 'none', dkim: dkim || 'none', dmarc: dmarc || 'none', compauth: compauth || 'none', header_from: headerFrom, sender_domain: senderDomain },
    link_domains: linkDomains,
    history: { key: histKey, malicious: pastBad, legitimate: pastGood },
    rubric_version: 'public-2026-11'
  };
}

// ===== n8n wrapper =====
// Expects an earlier node 'Restore Reports Summary' (one item: sender, reply_to, subject, body_excerpt, links,
// attachments, authentication, internet_message_id, report_id) and 'Sender History' (past reports with
// message_json, outcome, review_json, createdAt). Rename to match your workflow.
const report = $('Restore Reports Summary').first().json;
const history = $('Sender History').all().map(i => i.json).filter(j => j && j.message_json);
let result;
try { result = triage(report, history); }
catch (e) { result = { score: null, band: 'unknown', label: '⚪ Not rated (rubric error)', suggestion: 'Review manually', factors: [], tips: ['Automatic rating failed: ' + e.message], summary: '', sender_checks: {}, link_domains: {}, history: {} }; }
return [{ json: { ...report, triage: result } }];
