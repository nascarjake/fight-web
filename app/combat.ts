import { fighters, type Fighter, type Mode } from './data';
export type Action='light'|'heavy'|'special'|'finish'|'power'|'dash';
export type Input={left?:boolean;right?:boolean;jump?:boolean;crouch?:boolean;block?:boolean;action?:Action};
export type Body={id:number;def:Fighter;x:number;y:number;vy:number;vx:number;face:number;hp:number;guard:number;energy:number;boost:number;stun:number;cool:number;block:boolean;crouch:boolean;move:number;attack:Action|null;age:number;hit:boolean;combo:number;comboTime:number;buffer:Action|null;bufferTime:number};
export type Event={type:string;x:number;y:number;color:string;text?:string;side?:number};
export type Projectile={x:number;y:number;vx:number;life:number;side:number;damage:number;radius:number;color:string};
export const makeBody=(id:number,side:number):Body=>({id,def:fighters[id],x:side?4:-4,y:0,vy:0,vx:0,face:side?-1:1,hp:100,guard:100,energy:0,boost:0,stun:0,cool:0,block:false,crouch:false,move:0,attack:null,age:0,hit:false,combo:0,comboTime:0,buffer:null,bufferTime:0});
export class Combat{
 players:Body[];round=1;wins=[0,0];timer=99;phase:'intro'|'fight'|'round'|'over'='intro';phaseTime=2.2;events:Event[]=[];projectiles:Projectile[]=[];hitstop=0;winner=-1;roundWinner=-1;elapsed=0;aiClock=0;aiInput:Input={};
 constructor(public p1:number,public p2:number,public mode:Mode,public difficulty=.35,public random= Math.random){this.players=[makeBody(p1,0),makeBody(p2,1)]}
 emit(type:string,p:Body,text?:string){this.events.push({type,x:p.x,y:p.y+1.8,color:p.def.color,text,side:this.players.indexOf(p)})}
 nextRound(){this.players=[makeBody(this.p1,0),makeBody(this.p2,1)];this.projectiles=[];this.timer=99;this.round++;this.phase='intro';this.phaseTime=2.2;this.hitstop=0}
 finishRound(winner:number){if(this.phase!=='fight')return;this.roundWinner=winner;if(winner>=0)this.wins[winner]++;this.phase='round';this.phaseTime=3;this.projectiles=[];this.events.push({type:'round',x:0,y:0,color:'#dcf536',text:winner<0?'DRAW':this.timer<=0?'TIME UP':'K.O.'});if(winner>=0&&this.wins[winner]>=2){this.winner=winner}}
 ai(dt:number):Input{this.aiClock-=dt;if(this.aiClock>0)return {...this.aiInput,action:undefined};this.aiClock=.1+(1-this.difficulty)*.27;const [enemy,p]=this.players,dist=Math.abs(enemy.x-p.x),r=this.random();const towards=enemy.x>p.x;const i:Input={};if(dist>2.1){i.left=!towards;i.right=towards;if(dist>5&&r<.18)i.action='special';else if(dist>4&&r<.5*this.difficulty)i.action='dash'}else{if(enemy.attack&&r<.25+this.difficulty*.5)i.block=true;else i.action=r<.5?'light':r<.78?'heavy':'special';if(r>.86){i.left=towards;i.right=!towards}}if(r>.95)i.jump=true;if(p.energy>=100&&dist<3.5)i.action='finish';else if(p.energy>=50&&p.hp<40&&r<.15)i.action='power';this.aiInput=i;return i}
 attack(p:Body,action:Action){if(p.cool>0||p.stun>0)return false;
 if(action==='power'){if(p.energy<50||p.boost>0)return false;p.energy-=50;p.boost=6;p.cool=.25;this.emit('power',p,'OVERDRIVE');return true}
 if(action==='dash'){if(p.y>0)return false;p.vx=p.face*18;p.cool=.23;p.attack='dash';p.age=0;p.hit=true;this.emit('dash',p);return true}
 if(action==='finish'&&p.energy<100)return false;if(action==='special'&&p.energy<20)return false;
 if(action==='special')p.energy-=20;if(action==='finish'){p.energy=0;this.emit('finisher',p,p.def.finish)}
 p.attack=action;p.age=0;p.hit=false;p.block=false;p.cool=action==='light'?.26:action==='heavy'?.53:action==='special'?.62:1.15;return true}
 damage(attacker:Body,target:Body,amount:number,force:number,unblockable=false){if(target.hp<=0)return;const guarded=target.block&&target.guard>0&&target.y===0&&!unblockable;
 if(guarded){target.guard=Math.max(0,target.guard-amount*2.2);target.hp=Math.max(1,target.hp-amount*.07);target.stun=.08;target.vx=attacker.face*2;this.emit('block',target);if(target.guard===0){target.stun=1.1;target.block=false;this.emit('break',target,'GUARD BREAK')}}
 else{const scale=Math.max(.45,1-attacker.combo*.09);const damage=amount*attacker.def.power*(attacker.boost>0?1.3:1)*scale;target.hp=Math.max(0,target.hp-damage);target.stun=amount>20?.6:.19;target.attack=null;target.cool=Math.max(target.cool,target.stun);target.vx=attacker.face*force;attacker.combo++;attacker.comboTime=1;attacker.energy=Math.min(100,attacker.energy+amount*.8+4);target.energy=Math.min(100,target.energy+amount*.45);this.emit('hit',target,attacker.combo>1?`${attacker.combo} HIT`:undefined);if(amount>=16){target.vy=5;target.y+=.05}}
 this.hitstop=guarded?.035:amount>20?.12:.065;
 }
 resolve(p:Body,o:Body){const a=p.attack;if(!a||p.hit||p.age<(a==='light'?.07:a==='heavy'?.19:a==='special'?.15:.35))return;p.hit=true;const dist=Math.abs(p.x-o.x),vertical=Math.abs(p.y-o.y);const facing=(o.x-p.x)*p.face>=-.1;
 if(a==='special'){
 const kind=p.def.kind;
 if(['wave','shot','orb'].includes(kind)){this.projectiles.push({x:p.x+p.face,y:p.y+(kind==='wave'?.45:1.65),vx:p.face*(kind==='shot'?18:kind==='orb'?7:11),life:2,side:this.players.indexOf(p),damage:kind==='shot'?12:18,radius:kind==='orb'?.8:.5,color:p.def.color});this.emit('special',p,p.def.special);return}
 if(kind==='teleport'){p.x=Math.max(-9,Math.min(9,o.x-o.face*1.7));p.face=o.face;this.emit('special',p,p.def.special);if(vertical<2.1)this.damage(p,o,17,7);return}
 if(kind==='dash'){p.vx=p.face*22;p.hit=false;if(p.age<.48&&dist>p.def.reach)return;p.hit=true;}
 if(kind==='upper'){p.vy=9;p.y+=.03}
 if(dist<(kind==='grab'?2:p.def.reach+1)&&vertical<2.4&&facing){this.damage(p,o,kind==='grab'?26:20,9,kind==='grab');this.emit('special',p,p.def.special)}
 }else if(a==='finish'){if(dist<4.8&&vertical<3&&facing){this.damage(p,o,43,14);this.emit('explosion',o,p.def.finish)}}else if(a!=='dash'&&dist<p.def.reach+(a==='heavy'?.65:0)&&vertical<(p.crouch?1.3:2)&&facing){this.damage(p,o,a==='light'?6.5:13,a==='light'?3:6)}
 }
 step(dt:number,inputs:Input[]){this.elapsed+=dt;this.events=[];if(this.phase==='over')return;if(this.phase!=='fight'){this.phaseTime-=dt;if(this.phaseTime<=0){if(this.phase==='intro'){this.phase='fight';this.events.push({type:'start',x:0,y:0,color:'#dcf536',text:'LET’S ROCK'})}else if(this.winner>=0){this.phase='over'}else this.nextRound()}return}
 if(this.hitstop>0){this.hitstop-=dt;for(let n=0;n<2;n++)if(inputs[n]?.action){this.players[n].buffer=inputs[n].action!;this.players[n].bufferTime=.15}return}
 this.timer=Math.max(0,this.timer-dt);if(this.mode!=='local')inputs=[inputs[0]||{},this.ai(dt)];
 for(let n=0;n<2;n++){const p=this.players[n],o=this.players[1-n],i=inputs[n]||{};p.cool=Math.max(0,p.cool-dt);p.stun=Math.max(0,p.stun-dt);p.boost=Math.max(0,p.boost-dt);p.comboTime-=dt;if(p.comboTime<=0)p.combo=0;p.bufferTime-=dt;if(p.bufferTime<=0)p.buffer=null;
 if(i.action){p.buffer=i.action;p.bufferTime=.14}p.face=o.x>=p.x?1:-1;p.block=!!i.block&&p.stun<=0&&p.cool<=0&&p.guard>0&&p.y===0;p.crouch=!!i.crouch&&p.y===0;
 if(!p.block)p.guard=Math.min(100,p.guard+dt*12);else {const oldGuard=p.guard;p.guard=Math.max(0,p.guard-dt*5);if(oldGuard>0&&p.guard===0){p.block=false;p.stun=1.1;this.emit('break',p,'GUARD BREAK')}}p.energy=Math.min(100,p.energy+dt*1.1);
 if(p.buffer&&p.stun<=0&&p.cool<=0){const action=p.buffer;if(this.attack(p,action)){if(action==='dash'&&(i.left||i.right))p.vx=(i.right?1:-1)*18;p.buffer=null}}
 p.move=0;if(p.stun<=0&&p.cool<=0){if(i.jump&&p.y===0){p.vy=10.6;p.y=.01;this.emit('jump',p)}if(!p.block){p.move=(Number(!!i.right)-Number(!!i.left))*(p.crouch?.3:1);p.x+=p.move*p.def.speed*(p.boost>0?1.12:1)*dt}}
 p.x+=p.vx*dt;p.vx*=Math.exp(-dt*10);p.vy-=27*dt;p.y=Math.max(0,p.y+p.vy*dt);if(p.y===0)p.vy=0;p.x=Math.max(-9,Math.min(9,p.x));if(p.attack){p.age+=dt;this.resolve(p,o);if(p.cool<=0)p.attack=null}
 }
 const[a,b]=this.players;const gap=b.x-a.x;if(Math.abs(gap)<1.2&&Math.abs(a.y-b.y)<1.6){const push=(1.2-Math.abs(gap))*.5;const dir=gap>=0?1:-1;a.x=Math.max(-9,a.x-push*dir);b.x=Math.min(9,b.x+push*dir)}
 for(const shot of this.projectiles){shot.x+=shot.vx*dt;shot.life-=dt;const o=this.players[1-shot.side];if(Math.abs(shot.x-o.x)<shot.radius+.55&&Math.abs(shot.y-(o.y+(o.crouch?.7:1.3)))<shot.radius+.9){this.damage(this.players[shot.side],o,shot.damage,5);shot.life=0}}
 this.projectiles=this.projectiles.filter(s=>s.life>0&&Math.abs(s.x)<13);
 if(a.hp<=0||b.hp<=0)this.finishRound(a.hp===b.hp?-1:a.hp>b.hp?0:1);else if(this.timer<=0)this.finishRound(Math.abs(a.hp-b.hp)<.001?-1:a.hp>b.hp?0:1);
 }
}
