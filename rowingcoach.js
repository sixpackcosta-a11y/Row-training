const AdmZip=require('adm-zip');

function elapsedSeconds(value){
  const parts=String(value||'').trim().split(':').map(Number);
  if(!parts.length||parts.some(Number.isNaN))return null;
  return parts.reduce((total,n)=>total*60+n,0);
}

function csvRows(text){
  const lines=String(text||'').replace(/^\uFEFF/,'').split(/\r?\n/).filter(Boolean);
  if(lines.length<2)return [];
  const headers=lines[0].split(',').map(x=>x.trim());
  return lines.slice(1).map(line=>{
    const values=line.split(',');
    return Object.fromEntries(headers.map((header,index)=>[header,values[index]??'']));
  });
}

function parseCsv(text){
  const rows=csvRows(text).map(row=>({
    clock:String(row['hh:mm:ss']||''),
    elapsed:elapsedSeconds(row.sec),
    distance:Number(row.m||0),
    strokes:Number(row.str||0),
    currentSpm:Number(row['/min']||0),
    averagePace:String(row.avg||''),
    strokeLength:Number(row.len||0)
  })).filter(row=>row.elapsed!==null&&Number.isFinite(row.distance));
  if(!rows.length)return [];
  const groups=[];let current=[];
  for(const row of rows){
    if(current.length&&row.elapsed<current[current.length-1].elapsed){groups.push(current);current=[]}
    current.push(row);
  }
  if(current.length)groups.push(current);
  return groups.map((group,index)=>{
    const duration=Math.max(...group.map(x=>x.elapsed));
    const distance=Math.max(...group.map(x=>x.distance));
    const strokes=Math.max(...group.map(x=>x.strokes));
    const atMax=group.slice().sort((a,b)=>(b.distance-a.distance)||(b.elapsed-a.elapsed))[0];
    const pace=duration>0&&distance>0?duration*500/distance:null;
    const spm=duration>0&&strokes>0?strokes*60/duration:null;
    return {
      index:index+1,
      start_time:group[0]?.clock||null,
      end_time:group[group.length-1]?.clock||null,
      duration_seconds:duration,
      distance_m:Math.round(distance),
      pace_500_seconds:pace==null?null:Number(pace.toFixed(1)),
      source_average_pace:atMax?.averagePace||null,
      strokes:strokes||null,
      average_spm:spm==null?null:Number(spm.toFixed(1)),
      ending_spm:atMax?.currentSpm||null,
      stroke_length_m:atMax?.strokeLength||null,
      suggested:duration>=45&&distance>=100
    };
  });
}

function csvFromAttachment(filename,content){
  const name=String(filename||'').toLowerCase();
  if(name.endsWith('.csv'))return {filename,content:Buffer.from(content).toString('utf8')};
  if(!name.endsWith('.zip'))return null;
  const zip=new AdmZip(Buffer.from(content));
  const entry=zip.getEntries().find(item=>!item.isDirectory&&item.entryName.toLowerCase().endsWith('.csv'));
  if(!entry)return null;
  return {filename:entry.entryName,content:entry.getData().toString('utf8')};
}

function logDate(filename,fallback){
  const match=String(filename||'').match(/(20\d{2}-\d{2}-\d{2})T/);
  if(match)return match[1];
  const date=fallback instanceof Date?fallback:new Date(fallback||Date.now());
  return Number.isNaN(date.getTime())?null:date.toISOString().slice(0,10);
}

function parseAttachment(filename,content,emailDate){
  const csv=csvFromAttachment(filename,content);if(!csv)return null;
  const series=parseCsv(csv.content);
  if(!series.length)return null;
  return {filename:String(filename||csv.filename),csv_filename:csv.filename,date:logDate(filename,emailDate),series};
}

module.exports={parseAttachment,parseCsv,elapsedSeconds};
