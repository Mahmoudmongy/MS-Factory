
const SUPABASE_URL = 'https://kkigcqkjsdsbwkxlvdbb.supabase.co';
let SUPABASE_KEY = localStorage.getItem('sb_publishable_key') || 'sb_publishable_UoB-U4hKdZIo8Mjochzo4g_-pty5ySV';
if(!localStorage.getItem('sb_publishable_key')) localStorage.setItem('sb_publishable_key', SUPABASE_KEY);

function setSupabaseKey(k){ 
  SUPABASE_KEY = k; 
  localStorage.setItem('sb_publishable_key', k);
  initSupabase();
}

let sb = { ready: false };

async function sbFetch(table, method='GET', body=null, query=''){
  const url = `${SUPABASE_URL}/rest/v1/${table}${query}`;
  const headers = {
    'apikey': SUPABASE_KEY,
    'Authorization': `Bearer ${SUPABASE_KEY}`,
    'Content-Type': 'application/json',
    'Prefer': 'return=representation'
  };
  const opts = { method, headers };
  if(body) opts.body = JSON.stringify(body);
  try{
    const res = await fetch(url, opts);
    const data = await res.json().catch(()=>null);
    if(!res.ok) return { error: data, data: null };
    return { data, error: null };
  }catch(e){
    return { error: e.message, data: null };
  }
}

function initSupabase(){
  if(!SUPABASE_URL || !SUPABASE_KEY){ console.log('Supabase key not set'); return; }
  sb.ready = true;
  sb.from = (table) => ({
    select: (cols='*') => ({
      eq: (col, val) => ({
        single: async () => {
          return await sbFetch(table, 'GET', null, `?${col}=eq.${encodeURIComponent(val)}&limit=1`);
        }
      }),
      single: async () => {
        return await sbFetch(table, 'GET', null, '?limit=1');
      }
    }),
    insert: async (payload) => {
      return await sbFetch(table, 'POST', payload);
    },
    update: (payload) => ({
      eq: (col, val) => sbFetch(table, 'PATCH', payload, `?${col}=eq.${encodeURIComponent(val)}`)
    }),
    delete: () => ({
      eq: (col, val) => sbFetch(table, 'DELETE', null, `?${col}=eq.${encodeURIComponent(val)}`)
    })
  });
  console.log('✅ Supabase initialized (fetch mode) - no CDN needed');
  updateSyncStatus('online');
}

const IDB_NAME='factory_mgr_offline';
const IDB_VER=1;
function openDB(){
  return new Promise((res,rej)=>{
    const r=indexedDB.open(IDB_NAME, IDB_VER);
    r.onupgradeneeded=e=>{
      const db=e.target.result;
      if(!db.objectStoreNames.contains('queue')){
        const q=db.createObjectStore('queue', {keyPath:'id', autoIncrement:true});
        q.createIndex('status','status');
        q.createIndex('idempotency_key','idempotency_key',{unique:true});
      }
      if(!db.objectStoreNames.contains('local_data')){
        db.createObjectStore('local_data', {keyPath:'key'});
      }
    };
    r.onsuccess=()=>res(r.result);
    r.onerror=()=>rej(r.error);
  });
}

async function enqueue(table_name, op, payload){
  const idempotency_key = `${table_name}_${op}_${Date.now()}_${Math.random().toString(36).slice(2)}`;
  const entry = {
    client_id: payload.id || Date.now(),
    table_name, op, payload,
    status: 'pending',
    attempts: 0,
    idempotency_key,
    created_at: new Date().toISOString()
  };
  const db=await openDB();
  await new Promise((res,rej)=>{
    const tx=db.transaction('queue','readwrite');
    tx.objectStore('queue').add(entry);
    tx.oncomplete=res; tx.onerror=()=>rej(tx.error);
  });
  if(navigator.onLine) syncQueue();
  return idempotency_key;
}

async function syncQueue(){
  if(!sb.ready){ console.log('sb not ready'); return; }
  if(!navigator.onLine){ updateSyncStatus('offline'); return; }
  const db=await openDB();
  const pending = await new Promise((res)=>{
    const tx=db.transaction('queue','readonly');
    const req=tx.objectStore('queue').index('status').getAll('pending');
    req.onsuccess=()=>res(req.result);
    req.onerror=()=>res([]);
  });
  if(!pending.length){ updateSyncStatus('online'); return; }
  updateSyncStatus('syncing');
  for(const item of pending){
    try{
      const {data: existing} = await sb.from('idempotency_keys').select('key').eq('key', item.idempotency_key).single();
      if(existing && existing.data && existing.data.length){ 
        await markDone(item.id);
        continue;
      }
      let result;
      if(item.op==='insert'){
        result = await sb.from(item.table_name).insert(item.payload);
      } else if(item.op==='update'){
        result = await sb.from(item.table_name).update(item.payload).eq('id', item.payload.id);
      } else if(item.op==='delete'){
        result = await sb.from(item.table_name).delete().eq('id', item.payload.id);
      }
      if(result.error) throw result.error;
      await sb.from('idempotency_keys').insert({key: item.idempotency_key, response: {ok:true}});
      await markDone(item.id);
    }catch(e){
      console.error('sync failed', e);
      await markFailed(item.id, e.message||String(e));
    }
  }
  updateSyncStatus('online');
}

async function markDone(id){
  const db=await openDB();
  return new Promise((res)=>{
    const tx=db.transaction('queue','readwrite');
    const store=tx.objectStore('queue');
    const req=store.get(id);
    req.onsuccess=()=>{
      const val=req.result;
      if(val){ val.status='done'; store.put(val); }
    };
    tx.oncomplete=res;
  });
}

async function markFailed(id, err){
  const db=await openDB();
  return new Promise((res)=>{
    const tx=db.transaction('queue','readwrite');
    const store=tx.objectStore('queue');
    const req=store.get(id);
    req.onsuccess=()=>{
      const val=req.result;
      if(val){ val.status='failed'; val.attempts=(val.attempts||0)+1; val.error=err; store.put(val); }
    };
    tx.oncomplete=res;
  });
}

function updateSyncStatus(st){
  const el=document.getElementById('sync-indicator');
  if(el){
    const map={online:'🟢 متصل', offline:'🔴 غير متصل', syncing:'🟡 جاري المزامنة', pending:'🟠 في انتظار'};
    el.textContent=map[st]||st;
    el.className='sync-'+st;
  }
}

window.addEventListener('online', ()=>{ updateSyncStatus('online'); syncQueue(); });
window.addEventListener('offline', ()=>{ updateSyncStatus('offline'); });

window.FM_Supabase = { initSupabase, setSupabaseKey, enqueue, syncQueue, openDB, sbFetch };
document.addEventListener('DOMContentLoaded', initSupabase);
