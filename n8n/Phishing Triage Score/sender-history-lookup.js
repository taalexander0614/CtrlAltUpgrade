// ===== Sender history lookup (n8n Code node, runs before the rubric) =====
// Sanitized copy. License: GPL-3.0.
// Pick whose history to look up: the outside sharer for Drive/DocuSign/etc. shares, otherwise the sender.
// The real address is the one inside ‹ › (not a display name), or the last address in the string.
// Freemail senders are looked up by full address, everyone else by domain.
const OUR_DOMAIN = 'example.org'; // your mail domain
const r = $('Restore Reports Summary').first().json;
const norm = v => (v == null ? '' : String(v)).normalize('NFKC').toLowerCase();
const FREEMAIL = ['gmail.com','yahoo.com','outlook.com','hotmail.com','live.com','aol.com','icloud.com','me.com','proton.me','protonmail.com','gmx.com','mail.com','zoho.com','yandex.com'];
const FILE_SHARE = /^(drive-shares(-dm)?-noreply@google\.com|comments-noreply@docs\.google\.com|no-reply@sharepointonline\.com|no-reply@onedrive\.com|dse(_na\d)?@docusign\.net|no-reply@dropbox\.com|noreply@box\.com|no-reply@notify\.box\.com)$/;
const addrOf = v => {
  const s = norm(v);
  const b = s.match(/[‹<]\s*([^‹›<>\s]+@[^‹›<>\s]+)\s*[›>]/);
  const all = [...(b ? b[1] : s).matchAll(/[\p{L}\p{N}._%+-]+@[\p{L}\p{N}-]+(?:\.[\p{L}\p{N}-]+)+/gu)].map(m => m[0]);
  return all.length ? all[all.length - 1] : '';
};
const sender = addrOf(r.sender);
const who = FILE_SHARE.test(sender) ? addrOf(r.reply_to) : sender;
const domain = who.split('@')[1] || '';
const ours = !domain || domain === OUR_DOMAIN || domain.endsWith('.' + OUR_DOMAIN);
const free = FREEMAIL.some(f => domain === f || domain.endsWith('.' + f));
// message_json stores addresses with a full-width ＠; in ilike '_' matches any one character, so it matches it.
const pattern = ours ? '%no-history-lookup-for-internal%' : free ? '%' + who.replace('@', '_') + '%' : '%' + domain + '%';
return [{ json: { history_domain: ours ? '' : (free ? who : domain), history_pattern: pattern } }];
