// Draft planning geometry only. Does not use Blender, Studio, or any network.
// Writes only new files next to this script; refuses to overwrite.
import fs from 'node:fs';
import path from 'node:path';
import {fileURLToPath} from 'node:url';
const root=path.dirname(fileURLToPath(import.meta.url));
const write=(name,value)=>fs.writeFileSync(path.join(root,name),value,{flag:'wx'});
const pieces={
  gmLandmark:{count:1,trianglesTarget:6000,dimensionsStuds:[40,37,38],clearanceRadius:7,boundsRadius:20},
  gmTrumpet:{count:16,trianglesTarget:1800,dimensionsStuds:[12,15,12],clearanceRadius:7,boundsRadius:7},
  gmUmbrella:{count:14,trianglesTarget:1600,dimensionsStuds:[14,9,12],clearanceRadius:8,boundsRadius:8},
  gmBlob:{count:13,trianglesTarget:1000,dimensionsStuds:[8,4.5,7],clearanceRadius:5.5,boundsRadius:5.5},
  gmPool:{count:6,trianglesTarget:1200,dimensionsStuds:[48,0.8,48],clearanceRadius:24,boundsRadius:24},
  gmDNAVein:{count:7,trianglesTarget:1400,dimensionsStuds:[8,6,7],clearanceRadius:5.5,boundsRadius:5.5},
  gmNest:{count:3,trianglesTarget:1900,dimensionsStuds:[32,15,24],clearanceRadius:20,boundsRadius:20}
};
const routes=[
  {id:'entry',width:18,points:[[-490,0],[-535,0]]},
  {id:'east-spine',width:18,points:[[-535,-300],[-535,300]]},
  {id:'north-nest-approach',width:18,points:[[-535,-190],[-650,-150],[-668,-135]]},
  {id:'middle-nest-approach',width:18,points:[[-535,-35],[-618,-35]]},
  {id:'south-nest-approach',width:18,points:[[-535,95],[-620,115],[-648,140]]}
];
const pools=[[-600,-120,34],[-700,40,46],[-770,-200,28],[-590,180,30],[-760,230,24],[-640,-260,26]];
const placements=[];
function add(piece,x,z,yaw,scale=1,note=''){
  const def=pieces[piece], s=Array.isArray(scale)?scale:[scale,scale,scale];
  const id=piece+'_'+String(placements.filter(p=>p.piece===piece).length+1).padStart(2,'0');
  placements.push({id,piece,x,z,rotationYDegrees:yaw,scale:s,y:null,yPlanApprox:piece==='gmLandmark'?0:-6,
    seating:piece==='gmPool'?'Measure each existing dip; set the top just below its rim, with no exposed side wall. Do not infer a common y.':'Raycast terrain at the footprint and seat base at origin; check all edges.',
    groundExclusionRadius:Number((def.clearanceRadius*Math.max(s[0],s[2])).toFixed(3)),
    fullXZBoundsRadius:Number((def.boundsRadius*Math.max(s[0],s[2])).toFixed(3)),note});
}
add('gmLandmark',-511,-35,0,1,'37-stud planned height; cap underside >=15 studs; full cap stays inside marsh. Trunk leaves entry clear. Sightlines require Studio verification.');
for(const [x,z,r] of pools)add('gmPool',x,z,0,[r/24,1,r/24],'Opaque low relief surface scaled to the existing terrain dip radius. No transparent layers.');
for(const [x,z] of [[-650,-35],[-680,140],[-700,-135]])add('gmNest',x,z,-90,1,'Default authored front is -Z. Rotation -90 degrees faces +X, toward the approach. Entry and battle staging space require measured model and Studio checks.');
function distance(a,b){return Math.hypot(a[0]-b[0],a[1]-b[1]);}
function segmentDistance(p,a,b){
  const dx=b[0]-a[0],dz=b[1]-a[1];
  const t=Math.max(0,Math.min(1,((p[0]-a[0])*dx+(p[1]-a[1])*dz)/(dx*dx+dz*dz)));
  return distance(p,[a[0]+t*dx,a[1]+t*dz]);
}
function routeMargin(p){
  let m=Infinity;
  for(const r of routes)for(let i=1;i<r.points.length;i++)
    m=Math.min(m,segmentDistance([p.x,p.z],r.points[i-1],r.points[i])-r.width/2-p.groundExclusionRadius);
  return m;
}
function inside(p){let r=p.fullXZBoundsRadius;return p.x-r>=-830 && p.x+r<=-490 && p.z-r>=-330 && p.z+r<=330;}
let seed=301026;
function rng(){seed=(1664525*seed+1013904223)>>>0;return seed/4294967296;}
for(const piece of ['gmTrumpet','gmUmbrella','gmBlob','gmDNAVein']){
  for(let n=0;n<pieces[piece].count;n++){
    let found=false;
    for(let attempt=0;attempt<10000;attempt++){
      const pool=pools[(n+Math.floor(attempt/12))%pools.length];
      const a=rng()*Math.PI*2,rad=pool[2]+12+rng()*35;
      const x=Math.round(pool[0]+Math.cos(a)*rad),z=Math.round(pool[1]+Math.sin(a)*rad);
      const scale=Math.round((0.85+rng()*0.35)*100)/100;
      const p={x,z,groundExclusionRadius:pieces[piece].clearanceRadius*scale,fullXZBoundsRadius:pieces[piece].boundsRadius*scale};
      if(!inside(p)||routeMargin(p)<1)continue;
      if(placements.some(q=>distance([x,z],[q.x,q.z])<p.fullXZBoundsRadius+q.fullXZBoundsRadius+2))continue;
      add(piece,x,z,Math.round(rng()*360),scale,'Draft cluster placement; adjust only after terrain seating and actual mesh bounds are known.');
      found=true;break;
    }
    if(!found)throw new Error('Could not fit '+piece+' '+n);
  }
}
const counts=Object.fromEntries(Object.keys(pieces).map(k=>[k,placements.filter(p=>p.piece===k).length]));
const totalTarget=Object.entries(pieces).reduce((sum,[,p])=>sum+p.count*p.trianglesTarget,0);
const failures=[];
for(const [k,p] of Object.entries(pieces))if(counts[k]!==p.count)failures.push('count '+k);
for(const p of placements){
  if(!inside(p))failures.push('boundary '+p.id);
  if(routeMargin(p)<-0.001)failures.push('route '+p.id+' '+routeMargin(p));
}
for(let a=0;a<placements.length;a++)for(let b=a+1;b<placements.length;b++){
  const p=placements[a],q=placements[b];
  if(distance([p.x,p.z],[q.x,q.z])<p.fullXZBoundsRadius+q.fullXZBoundsRadius)failures.push('overlap '+p.id+' '+q.id);
}
const record={
  status:'DRAFT_UNREVIEWED_NOT_FOR_IMPORT',task:'TASK A Goo Marsh',units:'studs',coordinates:'Roblox X/Y/Z; north=-Z',
  rotationConvention:'Roblox Y rotation in degrees. Model front=-Z before yaw; -90 faces +X.',
  disclaimer:'All dimensions, triangle counts and exclusion radii are proposed. No mesh, terrain query, raycast, or in-game sightline was measured.',
  zone:{x:[-830,-490],z:[-330,330],floorApproxY:-6},pieces,routes,placements,
  plannedPlacementCount:placements.length,plannedTriangleTarget:totalTarget,
  requiredSightlineOrigins:[{plot:1,x:-230,z:-190,eyeYApprox:10.2},{plot:2,x:-230,z:-65,eyeYApprox:10.2},{plot:3,x:-230,z:65,eyeYApprox:10.2},{plot:4,x:-230,z:190,eyeYApprox:10.2}],
  nextValidation:'ChatGPT Thinking spec review. Then measured model bounds and triangle counts; then Studio terrain seating, >=14-stud actual lanes, landmark visibility, and phone performance.'
};
const validation={
  status:failures.length?'FAIL':'PASS_PLANNING_GEOMETRY_ONLY',
  placementCount:placements.length,pieceCounts:counts,plannedTriangleTarget:totalTarget,
  minimumProtectedRouteWidth:18,minimumExtraClearanceBeyondProtectedRoute:Number(Math.min(...placements.map(routeMargin)).toFixed(3)),
  zoneBoundaryChecks:'Conservative full XZ circles',overlapChecks:'Conservative full XZ circles',
  actualMeshCounts:'NOT_BUILT',actualTerrainSeating:'NOT_TESTED',actualWalkability:'NOT_TESTED',
  actualSightlines:'NOT_TESTED',ChatGPTThinkingVerdict:'NONE_NOT_SUBMITTED',failures
};
if(failures.length)throw new Error(JSON.stringify(validation,null,2));
write('placement-draft.json',JSON.stringify(record,null,2)+'\n');
write('placement-check.json',JSON.stringify(validation,null,2)+'\n');
const colors={gmLandmark:'#268cae',gmTrumpet:'#6ac7d8',gmUmbrella:'#a4dce3',gmBlob:'#4892bb',gmPool:'#86dce3',gmDNAVein:'#135b7c',gmNest:'#8777ad'};
const X=x=>60+(x+830),Z=z=>75+(z+330);
let svg='<svg xmlns="http://www.w3.org/2000/svg" width="700" height="820" viewBox="0 0 700 820"><rect width="700" height="820" fill="#f5f5f7"/><g font-family="Arial,sans-serif"><text x="30" y="28" font-size="21" fill="#202c3c">GOO MARSH · DRAFT PLACEMENT</text><text x="30" y="50" font-size="12" fill="#525a66">60 proposed placements · north = −Z · no terrain or mesh verification</text><rect x="60" y="75" width="340" height="660" fill="#e2e0e6" stroke="#837e8d"/>';
for(const route of routes)svg+='<polyline points="'+route.points.map(([x,z])=>X(x)+','+Z(z)).join(' ')+'" fill="none" stroke="#fff" stroke-width="'+route.width+'" stroke-linecap="round" stroke-linejoin="round"/>';
for(const p of placements){
  svg+='<circle cx="'+X(p.x)+'" cy="'+Z(p.z)+'" r="'+p.fullXZBoundsRadius+'" fill="'+colors[p.piece]+'" fill-opacity=".8" stroke="#364353" stroke-width=".6"/>';
  if(p.piece==='gmNest')svg+='<text x="'+X(p.x)+'" y="'+(Z(p.z)+4)+'" text-anchor="middle" font-size="11" fill="white">N</text>';
  if(p.piece==='gmLandmark')svg+='<text x="'+X(p.x)+'" y="'+(Z(p.z)+4)+'" text-anchor="middle" font-size="11" fill="white">L</text>';
}
svg+='<text x="425" y="95" font-size="16" fill="#202c3c">Planning key</text>';
Object.keys(pieces).forEach((k,i)=>{svg+='<circle cx="435" cy="'+(123+i*30)+'" r="7" fill="'+colors[k]+'"/><text x="451" y="'+(127+i*30)+'" font-size="13">'+k.replace('gm','')+' × '+counts[k]+'</text>';});
svg+='<text x="425" y="366" font-size="12">White routes: 18 studs wide</text><text x="425" y="390" font-size="12">Landmark: entrance, 37 studs tall</text><text x="425" y="414" font-size="12">Pools: six existing terrain dips</text><text x="425" y="438" font-size="12">Y: intentionally unresolved</text><text x="425" y="480" font-size="12" fill="#835d2e">NOT REVIEWED / NOT FOR IMPORT</text><text x="60" y="760" font-size="12">Zone X −830..−490; Z −330..330. Circles are conservative planned bounds.</text><text x="60" y="784" font-size="12">ChatGPT spec GO is still required before any Blender build.</text></g></svg>';
write('placement-plan.svg',svg+'\n');
console.log(JSON.stringify(validation,null,2));
