export const fighters = [
 {name:'KAI',title:'The burning renegade',style:'BALANCED',color:'#ff4c35',speed:6.1,power:1,reach:2.5,special:'Inferno Drive',finish:'WORLD ON FIRE',kind:'wave',weapon:'sword',quote:'Some things are worth burning for.'},
 {name:'YUKI',title:'Silence before the storm',style:'PRECISION',color:'#78e6ff',speed:7.2,power:.85,reach:2.3,special:'Glacial Fang',finish:'ABSOLUTE ZERO',kind:'dash',weapon:'blade',quote:'Even the storm falls silent.'},
 {name:'ROOK',title:'The last line of defense',style:'GRAPPLER',color:'#ffab42',speed:4.2,power:1.45,reach:2.1,special:'Seismic Break',finish:'EXTINCTION EVENT',kind:'grab',weapon:'fists',quote:'You cannot move a mountain.'},
 {name:'VEX',title:'A beautiful nightmare',style:'MIX-UP',color:'#b881ff',speed:7.5,power:.8,reach:2.4,special:'Shadow Slip',finish:'INTO THE VOID',kind:'teleport',weapon:'blade',quote:'You never saw the real me.'},
 {name:'RAIJIN',title:'Born at the speed of thunder',style:'RUSHDOWN',color:'#e4ff43',speed:8,power:.8,reach:2.2,special:'Thunder Rush',finish:'GOD OF THUNDER',kind:'dash',weapon:'fists',quote:'Try to keep up.'},
 {name:'SABLE',title:'One last dance with death',style:'ZONER',color:'#ff5f89',speed:5.5,power:.95,reach:2.8,special:'Crimson Bullet',finish:'LAST RITES',kind:'shot',weapon:'gun',quote:'Every ending needs a little style.'},
 {name:'ONI',title:'The rage beneath the skin',style:'BRAWLER',color:'#ff372d',speed:5,power:1.3,reach:2.3,special:'Demon Claw',finish:'HELL UNLEASHED',kind:'upper',weapon:'fists',quote:'That was only the beginning.'},
 {name:'NOVA',title:'Trouble from another orbit',style:'SETPLAY',color:'#38ffd6',speed:6.2,power:.95,reach:2.5,special:'Orbital Strike',finish:'SUPERNOVA',kind:'orb',weapon:'gun',quote:'See you on the other side of the stars.'},
 {name:'ZERO',title:'No name. No mercy.',style:'COUNTER',color:'#c4dcff',speed:7,power:.9,reach:3,special:'Ghost Cut',finish:'SYSTEM ERASURE',kind:'dash',weapon:'sword',quote:'Target eliminated.'},
 {name:'IVY',title:'Every rose has its victims',style:'CONTROL',color:'#a0ef61',speed:5.7,power:1,reach:3.1,special:'Thorn Requiem',finish:'GARDEN OF RUIN',kind:'wave',weapon:'staff',quote:'Beautiful things can hurt you.'},
 {name:'ATLAS',title:'The weight of a fallen world',style:'POWER',color:'#ffd275',speed:4.5,power:1.4,reach:2.7,special:'Titan Hammer',finish:'HEAVEN FALLS',kind:'upper',weapon:'hammer',quote:'Stand tall. Even in defeat.'},
 {name:'ECHO',title:'Turn the world up to eleven',style:'TRICKSTER',color:'#ff8cde',speed:6.8,power:.85,reach:2.8,special:'Feedback Loop',finish:'FINAL ENCORE',kind:'orb',weapon:'staff',quote:'Make some noise for the winner.'},
] as const;
export type Fighter = typeof fighters[number];
export const stages = [
 {name:'NEON SHINJUKU',region:'TOKYO, JAPAN',tag:'MIDNIGHT / RAIN',color:'#ff3568',secondary:'#4de4ff',type:'city'},
 {name:'IRON CATHEDRAL',region:'THE FORGOTTEN DISTRICT',tag:'GOTHIC / EMBERS',color:'#ff9546',secondary:'#a970ff',type:'cathedral'},
 {name:'DEAD FREQUENCY',region:'PIRATE RADIO STATION',tag:'ROOFTOP / STORM',color:'#c489ff',secondary:'#ff4288',type:'rooftop'},
 {name:'THE FOUNDRY',region:'SECTOR 09',tag:'INDUSTRIAL / MOLTEN',color:'#ff571f',secondary:'#ffcc44',type:'foundry'},
 {name:'SAKURA GRAVE',region:'KYOTO OUTSKIRTS',tag:'SHRINE / PETALS',color:'#ffa1c8',secondary:'#8aceff',type:'shrine'},
 {name:'DEEP BLUE',region:'ABYSSAL OBSERVATORY',tag:'UNDERWATER / BIOLUMINESCENT',color:'#36e6eb',secondary:'#677aff',type:'ocean'},
 {name:'SUNSET WASTES',region:'THE OUTLANDS',tag:'DESERT / DUST',color:'#ffb65e',secondary:'#e65781',type:'desert'},
 {name:'EVENT HORIZON',region:'LOW EARTH ORBIT',tag:'ORBITAL / ZERO GRAVITY',color:'#9890ff',secondary:'#40fff0',type:'space'},
] as const;
export type Mode = 'cpu' | 'local' | 'arcade';
