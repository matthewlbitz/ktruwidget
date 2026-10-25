const {DatabaseSync}=require('node:sqlite');
const {allocate}=require('./shelf-allocation');
const fs=require('node:fs');
function lookup(filename,barcode){
 if(!filename || !fs.statSync(filename).isFile()) throw Error('Select an existing catalog database.');
 const db=new DatabaseSync(filename,{readOnly:true,allowExtension:false});
 try {
  db.exec('PRAGMA query_only=ON; PRAGMA busy_timeout=1500; BEGIN');
  const columns=db.prepare('PRAGMA table_info(rainbow_albums)').all().map(x=>x.name);
  for(const name of ['id','barcode','artist','artist_sort','title','primary_genre','secondary_genre','final_shelf'])
   if(!columns.includes(name)) throw Error('Unsupported catalog schema: missing '+name);
  const code=String(barcode??'').trim();
  if(!code || code.length>256) return {status:'invalid',message:'Scan a barcode (maximum 256 characters).'};
  const matches=db.prepare('SELECT * FROM rainbow_albums WHERE barcode = ?').all(code);
  if(!matches.length) return {status:'unknown',message:'Unknown barcode: '+code};
  if(matches.length!==1) return {status:'duplicate',message:'Duplicate barcode: '+code+'. Resolve in Shelf Lookup.'};
  const album=matches[0];
  const shelf=String(album.final_shelf??'').trim();
  if(!shelf) return {status:'unassigned',album,message:'No final shelf assigned.'};
  const rows=db.prepare('SELECT * FROM rainbow_albums WHERE final_shelf = ?').all(album.final_shelf);
  // Canonical allocator supplies ordering; stored assignments are authoritative.
  const report=allocate(rows);
  const index=report.ordered_albums.findIndex(a=>a.id===album.id);
  const incomplete=report.excluded.length>0;
  return {status:'found',album,shelf,position:index<0||incomplete?null:index+1,total:rows.length,
   message:incomplete?'Position unavailable: shelf has unresolved sorting metadata.':'Canonical catalog order; physical placement is not verified.',
   previous:index>0&&!incomplete?report.ordered_albums[index-1]:null,
   next:index>=0&&!incomplete?report.ordered_albums[index+1]??null:null};
 } finally {db.close();}
}
module.exports={lookup};
if(require.main===module){
 try {console.log(JSON.stringify(lookup(process.argv[2],process.argv[3])));}
 catch(e){console.log(JSON.stringify({status:'error',message:e.message}));process.exitCode=1;}
}
