// ==========================================================
// submit-lead — קליטת פניות מהטופס הציבורי באתר של נועם
//
// למה פונקציה ולא כתיבה ישירה מהדפדפן:
// הטופס פתוח לכל אחד. כתיבה ישירה מחייבת policy של anon,
// וזה פותח את הטבלה להצפה. כאן המפתח החזק יושב בשרת בלבד.
// ==========================================================

import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.45.4';

const CORS = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'content-type',
  'Access-Control-Allow-Methods': 'POST, OPTIONS'
};

const json = (body: unknown, status = 200) =>
  new Response(JSON.stringify(body), {
    status,
    headers: { ...CORS, 'Content-Type': 'application/json' }
  });

// סוג האירוע מגיע בעברית מהטופס. ממפים לערך של בסיס הנתונים.
const EVENT_MAP: Record<string, string> = {
  'חתונה': 'wedding',
  'בר מצווה': 'bar_mitzvah',
  'בת מצווה': 'bat_mitzvah',
  'אירוע עסקי': 'corporate',
  'יריד': 'corporate',
  'חינה': 'henna',
  'אירוע פרטי': 'birthday',
  'אחר': 'other'
};

const PREF: Record<string, string> = {
  whatsapp: 'מעדיף וואטסאפ',
  phone: 'מעדיף שיחה',
  both: 'וואטסאפ או שיחה'
};

function normalizePhone(raw: string) {
  const d = String(raw || '').replace(/\D/g, '');
  if (d.startsWith('972')) return '0' + d.slice(3);
  return d;
}

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: CORS });
  if (req.method !== 'POST') return json({ error: 'method_not_allowed' }, 405);

  let body: Record<string, string>;
  try {
    body = await req.json();
  } catch {
    return json({ error: 'bad_json' }, 400);
  }

  // מלכודת בוטים. שדה נסתר שרק סקריפט אוטומטי ממלא.
  if (body.company) return json({ ok: true });

  const full_name = String(body.name || '').trim().slice(0, 120);
  const phone     = normalizePhone(body.phone);

  if (full_name.length < 2)  return json({ error: 'name_required' }, 400);
  if (phone.length < 9 || phone.length > 11) return json({ error: 'phone_invalid' }, 400);

  const supabase = createClient(
    Deno.env.get('SUPABASE_URL')!,
    Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
  );

  // בלימת הצפה: אותו טלפון לא יפתח יותר מ-3 פניות ברבע שעה.
  const since = new Date(Date.now() - 15 * 60 * 1000).toISOString();
  const { count } = await supabase
    .from('leads')
    .select('id', { count: 'exact', head: true })
    .eq('phone', phone)
    .gte('created_at', since);

  if ((count ?? 0) >= 3) return json({ ok: true, throttled: true });

  // שומרים את מה שלא נכנס לעמודה ייעודית, כדי שלא יאבד מידע.
  const extras: string[] = [];
  const rawEvent = String(body.event_type || '').trim();
  if (rawEvent && !EVENT_MAP[rawEvent]) extras.push(`סוג האירוע כפי שנכתב: ${rawEvent}`);
  if (body.contact_pref && PREF[body.contact_pref]) extras.push(PREF[body.contact_pref]);

  const userMessage = String(body.message || '').trim().slice(0, 2000);
  const message = [userMessage, ...extras].filter(Boolean).join(' · ') || null;

  const { error } = await supabase.from('leads').insert({
    full_name,
    phone,
    event_kind : EVENT_MAP[rawEvent] || 'other',
    event_date : /^\d{4}-\d{2}-\d{2}$/.test(String(body.event_date)) ? body.event_date : null,
    message,
    source     : 'website',
    status     : 'new'
  });

  if (error) {
    console.error('insert failed:', error.message);
    return json({ error: 'insert_failed' }, 500);
  }

  return json({ ok: true });
});
