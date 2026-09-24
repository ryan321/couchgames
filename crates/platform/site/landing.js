(() => {
  'use strict';
  const $ = s => document.querySelector(s);
  const reduced = matchMedia('(prefers-reduced-motion: reduce)');
  let paused = reduced.matches;
  const palettes = [
    { name: 'Daydream', hex: '#a8f8bd', rgb: [0.66, 0.97, 0.74], couch: [0.25, 0.55, 0.37] },
    { name: 'After Hours', hex: '#c5b4ff', rgb: [0.77, 0.71, 1.0], couch: [0.37, 0.29, 0.58] },
    { name: 'Super Nova', hex: '#ffc39d', rgb: [1.0, 0.76, 0.62], couch: [0.58, 0.32, 0.22] }
  ];
  let dimension = 0, warpStart = -100, time = 0, pointerX = 0, pointerY = 0, smoothX = 0, smoothY = 0;
  let requestFrame = 0, last = 0, onScreen = true, scrollY = window.scrollY;
  const canvas = $('#universe');
  const hero = $('.hero');
  const motion = $('#motion');
  const orbit = $('#couch-orbit');
  let orientation = [0,0,0,1], drag = null;
  const observers = [];
  document.body.classList.toggle('js-motion', !paused);
  document.body.classList.toggle('paused', paused);
  // The copy remains readable if scripting, WebGL, or observers are unavailable.
  if ('IntersectionObserver' in window) {
    const reveal = new IntersectionObserver(entries => entries.forEach(e => {
      e.target.classList.toggle('is-visible', e.isIntersecting || paused);
    }), { threshold: .7, rootMargin: '0px 0px -8% 0px' });
    document.querySelectorAll('.reveal-line').forEach(el => reveal.observe(el));
    observers.push(reveal);
  } else document.body.classList.remove('js-motion');

  function selectDimension(index, warp = false) {
    dimension = index;
    const palette = palettes[index];
    document.documentElement.style.setProperty('--accent', palette.hex);
    document.documentElement.style.setProperty('--accent-rgb', palette.rgb.map(n => Math.round(n * 255)).join(','));
    document.querySelectorAll('[data-dimension]').forEach(b => b.setAttribute('aria-pressed', String(Number(b.dataset.dimension) === index)));
    $('#dimension-number').textContent = '0' + (index + 1);
    $('#dimension-status').textContent = palette.name + ' dimension';
    if (warp && !paused) warpStart = time;
    draw();
  }
  document.querySelectorAll('[data-dimension]').forEach(b => b.addEventListener('click', () => selectDimension(Number(b.dataset.dimension), true)));
  $('#warp').addEventListener('click', () => selectDimension((dimension + 1) % palettes.length, true));
  function syncMotion() {
    document.body.classList.toggle('paused', paused);
    document.body.classList.toggle('js-motion', !paused);
    motion.textContent = paused ? '▷' : 'Ⅱ';
    motion.setAttribute('aria-pressed', String(paused));
    motion.setAttribute('aria-label', paused ? 'Play animations' : 'Pause animations');
    last = 0;
    cancelAnimationFrame(requestFrame); requestFrame = 0;
    draw(); start();
  }
  motion.addEventListener('click', () => { paused = !paused; syncMotion(); });
  reduced.addEventListener('change', () => { paused = reduced.matches; syncMotion(); });
  hero.addEventListener('pointermove', e => {
    if (e.pointerType === 'touch' || paused || drag) return;
    const bounds = hero.getBoundingClientRect();
    pointerX = (e.clientX - bounds.left) / bounds.width * 2 - 1;
    pointerY = (e.clientY - bounds.top) / bounds.height * 2 - 1;
  });
  hero.addEventListener('pointerleave', () => { pointerX = 0; pointerY = 0; });
  document.addEventListener('visibilitychange', () => {
    last = 0;
    if (document.hidden) { cancelAnimationFrame(requestFrame); requestFrame = 0; } else start();
  });
  function updateScroll() {
    scrollY = window.scrollY;
    const max = document.documentElement.scrollHeight - innerHeight;
    document.documentElement.style.setProperty('--progress', max ? scrollY / max : 0);
    if (!paused) $('.hero-heading').style.transform = 'translateY(' + Math.min(scrollY * .2, 180) + 'px)';
    else $('.hero-heading').style.transform = '';
  }
  addEventListener('scroll', updateScroll, { passive: true });
  updateScroll();
  document.querySelectorAll('.magnetic').forEach(el => {
    el.addEventListener('pointermove', e => {
      if (paused || e.pointerType === 'touch') return;
      const r = el.getBoundingClientRect();
      el.style.transform = `translate(${(e.clientX-r.left-r.width/2)*.08}px, ${(e.clientY-r.top-r.height/2)*.15}px)`;
    });
    el.addEventListener('pointerleave', () => { el.style.transform = ''; });
  });

  // Small, dependency-free WebGL scene. No models, libraries, or runtimes to download.
  let gl, program, starsProgram, linesProgram, wireProgram, locations, starLocations, lineLocations, wireLocations;
  let couchParts = [], ringMeshes = [], controllerParts = [], starBuffer, dustBuffer, orbitBuffer;
  let gameCameos = [], cameoProgram, cameoLocations, cameoBuffer;
  const cameoImages = new Map();
  let currentColor = [...palettes[0].rgb], currentCouch = [...palettes[0].couch];
  let width = 0, height = 0, ready = false;
  let backdrop = null;
  const TAU = Math.PI * 2;
  const identity = () => [1,0,0,0,0,1,0,0,0,0,1,0,0,0,0,1];
  function multiply(a,b) {
    const out = new Array(16).fill(0);
    for(let c=0;c<4;c++) for(let r=0;r<4;r++) for(let k=0;k<4;k++) out[c*4+r]+=a[k*4+r]*b[c*4+k];
    return out;
  }
  function translation(x,y,z) { const m=identity();m[12]=x;m[13]=y;m[14]=z;return m; }
  function scale(x,y=x,z=x) { return [x,0,0,0,0,y,0,0,0,0,z,0,0,0,0,1]; }
  function rotationX(a) { const c=Math.cos(a),s=Math.sin(a);return [1,0,0,0,0,c,s,0,0,-s,c,0,0,0,0,1]; }
  function rotationY(a) { const c=Math.cos(a),s=Math.sin(a);return [c,0,-s,0,0,1,0,0,s,0,c,0,0,0,0,1]; }
  function rotationZ(a) { const c=Math.cos(a),s=Math.sin(a);return [c,s,0,0,-s,c,0,0,0,0,1,0,0,0,0,1]; }
  const compose = (...matrices) => matrices.reduce(multiply,identity());
  function normalize(a) { const l=Math.hypot(...a)||1;return a.map(n=>n/l); }
  function cross(a,b) {return [a[1]*b[2]-a[2]*b[1],a[2]*b[0]-a[0]*b[2],a[0]*b[1]-a[1]*b[0]];}
  // A quaternion trackball has no pitch limits or pole flips. Edge drags roll.
  function turn(q,render=true) {
    const [x,y,z,w]=q,[a,b,c,d]=orientation;
    orientation=normalize([w*a+x*d+y*c-z*b,w*b-x*c+y*d+z*a,w*c+x*b-y*a+z*d,w*d-x*a-y*b-z*c]);
    if(render)draw();
  }
  function orbitMatrix() {
    const [x,y,z,w]=orientation;
    return [1-2*(y*y+z*z),2*(x*y+z*w),2*(x*z-y*w),0,2*(x*y-z*w),1-2*(x*x+z*z),2*(y*z+x*w),0,2*(x*z+y*w),2*(y*z-x*w),1-2*(x*x+y*y),0,0,0,0,1];
  }
  function trackball(e) {
    const r=orbit.getBoundingClientRect(),radius=Math.min(r.width,r.height)*.65;
    const x=(e.clientX-r.left-r.width/2)/radius,y=(r.top+r.height/2-e.clientY)/radius;
    return normalize([x,y,Math.sqrt(Math.max(0,1-x*x-y*y))]);
  }
  function resetView(render=true) {
    orientation=[0,0,0,1];pointerX=pointerY=smoothX=smoothY=0;if(render)draw();
  }
  orbit.addEventListener('pointerdown', e => {
    if(!ready || !e.isPrimary || e.button!==0 || drag)return;
    orbit.classList.add('pointer-focus');
    orbit.focus({preventScroll:true});
    orbit.setPointerCapture(e.pointerId);
    drag={id:e.pointerId,point:trackball(e)};
    orbit.classList.add('is-dragging');
    e.preventDefault();
  });
  orbit.addEventListener('pointermove', e => {
    if(!drag || e.pointerId!==drag.id)return;
    const point=trackball(e),axis=cross(drag.point,point),dot=drag.point.reduce((n,v,i)=>n+v*point[i],0);
    if(Math.hypot(...axis)>1e-7)turn(normalize([...axis,1+dot]));
    drag.point=point;
  });
  function endDrag(e) {
    if(!drag || e.pointerId!==drag.id)return;
    drag=null;orbit.classList.remove('is-dragging');
    if(orbit.hasPointerCapture(e.pointerId))orbit.releasePointerCapture(e.pointerId);
  }
  ['pointerup','pointercancel','lostpointercapture'].forEach(name=>orbit.addEventListener(name,endDrag));
  orbit.addEventListener('blur',()=>orbit.classList.remove('pointer-focus'));
  orbit.addEventListener('keydown', e => {
    orbit.classList.remove('pointer-focus');
    const key=e.key.toLowerCase();
    if(key==='home'){e.preventDefault();resetView();return;}
    const axis={arrowleft:[0,-1,0],arrowright:[0,1,0],arrowup:[-1,0,0],arrowdown:[1,0,0],q:[0,0,1],e:[0,0,-1]}[key];
    if(!axis)return;
    e.preventDefault();
    const halfAngle=(e.shiftKey?15:7)*Math.PI/360;
    turn([...axis.map(n=>n*Math.sin(halfAngle)),Math.cos(halfAngle)]);
  });
  $('#reset-view').addEventListener('click',resetView);
  let resetButtons=new Set(),controllerPresent=null;
  const stickValue=n=>{n=Number.isFinite(n)?Math.max(-1,Math.min(1,n)):0;return Math.abs(n)<.18?0:Math.sign(n)*(Math.abs(n)-.18)/.82;};
  function pollControllers(dt) {
    let pads=[];
    try { pads=Array.from(navigator.getGamepads?.()||[]).filter(p=>p?.connected && p.mapping==='standard'); } catch (_) { /* Browser policy may disable the Gamepad API. */ }
    if(controllerPresent!==Boolean(pads.length)) {
      controllerPresent=Boolean(pads.length);
      document.body.classList.toggle('controller-ready',controllerPresent);
      $('#controller-hint').textContent=controllerPresent?'L STICK: TURN · R STICK: ROLL':'CONTROLLER? PRESS A BUTTON';
    }
    const held=new Set(pads.filter(p=>p.buttons[0]?.pressed).map(p=>p.index));
    const reset=pads.some(p=>held.has(p.index) && !resetButtons.has(p.index));
    resetButtons=held;
    if(!document.hasFocus() || drag)return false;
    if(reset){resetView(false);return true;}
    // Any active standard-mapped controller can take over. Idle sticks never drift.
    for(const pad of pads) {
      const axes=[stickValue(pad.axes[1]),stickValue(pad.axes[0]),-stickValue(pad.axes[2])];
      const speed=Math.hypot(...axes);
      if(!speed)continue;
      const halfAngle=speed*dt*.9;
      turn([...axes.map(n=>n/speed*Math.sin(halfAngle)),Math.cos(halfAngle)],false);
      return true;
    }
    return false;
  }
  function lookAt(eye,center) {
    const z=normalize(eye.map((n,i)=>n-center[i])),x=normalize(cross([0,1,0],z)),y=cross(z,x);
    return [x[0],y[0],z[0],0,x[1],y[1],z[1],0,x[2],y[2],z[2],0,-x.reduce((s,n,i)=>s+n*eye[i],0),-y.reduce((s,n,i)=>s+n*eye[i],0),-z.reduce((s,n,i)=>s+n*eye[i],0),1];
  }
  function perspective(fov,aspect,near,far) {const f=1/Math.tan(fov/2);return [f/aspect,0,0,0,0,f,0,0,0,0,(far+near)/(near-far),-1,0,0,2*far*near/(near-far),0];}
  function shader(type, source) {
    const s=gl.createShader(type);gl.shaderSource(s,source);gl.compileShader(s);
    if(!gl.getShaderParameter(s,gl.COMPILE_STATUS)) throw new Error('Scene shader could not compile: '+gl.getShaderInfoLog(s));
    return s;
  }
  function makeProgram(v,f) {
    const p=gl.createProgram(),vs=shader(gl.VERTEX_SHADER,v),fs=shader(gl.FRAGMENT_SHADER,f);
    gl.attachShader(p,vs);gl.attachShader(p,fs);gl.linkProgram(p);gl.deleteShader(vs);gl.deleteShader(fs);
    if(!gl.getProgramParameter(p,gl.LINK_STATUS)) throw new Error('Scene shader could not link: '+gl.getProgramInfoLog(p));
    return p;
  }
  function mesh(data) {const buffer=gl.createBuffer();gl.bindBuffer(gl.ARRAY_BUFFER,buffer);gl.bufferData(gl.ARRAY_BUFFER,new Float32Array(data),gl.STATIC_DRAW);return {buffer,count:data.length/6};}
  function roundBox(w,h,d,r,div=10,flat=false,puff=0) {
    const sizes=[w/2,h/2,d/2],data=[],wires=[];
    for(let axis=0;axis<3;axis++) for(const side of [-1,1]) {
      const u=(axis+1)%3,v=(axis+2)%3;
      function vertex(i,j) {
        const p=[0,0,0];p[axis]=sizes[axis]*side;p[u]=(i/div*2-1)*sizes[u];p[v]=(j/div*2-1)*sizes[v];
        const clamped=p.map((n,k)=>Math.max(-sizes[k]+r,Math.min(sizes[k]-r,n)));
        let normal=normalize(p.map((n,k)=>n-clamped[k]));
        const position=clamped.map((n,k)=>n+normal[k]*r);
        // Final cushions have a gently inflated surface, instead of a perfect box.
        if(puff && ((h<.5 && axis===1) || (d<.5 && axis===2))) {
          const pu=p[u]/sizes[u],pv=p[v]/sizes[v];
          const crease=(Math.sin(pu*31.0+pv*3.0)*Math.pow(Math.abs(pv),5)+Math.sin(pv*29.0+pu*4.0)*Math.pow(Math.abs(pu),5))*.018;
          const bulge=(puff+crease)*(1-pu*pu)*(1-pv*pv);
          position[axis]+=side*bulge;
          normal[u]+=2*puff*pu/sizes[u]*(1-pv*pv);
          normal[v]+=2*puff*pv/sizes[v]*(1-pu*pu);
          normal=normalize(normal);
        }
        return [...position,...normal];
      }
      for(let i=0;i<div;i++) for(let j=0;j<div;j++) {
        const a=vertex(i,j),b=vertex(i+1,j),c=vertex(i+1,j+1),d2=vertex(i,j+1);data.push(...a,...b,...c,...a,...c,...d2);
      }
      // Quad contours rather than triangle diagonals: a clean, curved Tron grid.
      for(let i=0;i<=div;i+=2) for(let j=0;j<div;j++) {
        wires.push(...vertex(i,j).slice(0,3),...vertex(i,j+1).slice(0,3));
        wires.push(...vertex(j,i).slice(0,3),...vertex(j+1,i).slice(0,3));
      }
    }
    if(flat) for(let i=0;i<data.length;i+=18) {
      const ab=[0,1,2].map(k=>data[i+6+k]-data[i+k]);
      const ac=[0,1,2].map(k=>data[i+12+k]-data[i+k]);
      let n=normalize(cross(ab,ac));
      if(n.reduce((sum,v,k)=>sum+v*data[i+3+k],0)<0)n=n.map(v=>-v);
      for(let corner=0;corner<3;corner++) for(let k=0;k<3;k++)data[i+corner*6+3+k]=n[k];
    }
    const result=mesh(data);
    result.shape=[w,h,d,r];
    result.wireBuffer=gl.createBuffer();result.wireCount=wires.length/3;
    gl.bindBuffer(gl.ARRAY_BUFFER,result.wireBuffer);
    gl.bufferData(gl.ARRAY_BUFFER,new Float32Array(wires),gl.STATIC_DRAW);
    return result;
  }
  function torus(radius,tube,segments=160,sides=8,arc=TAU) {
    const data=[];
    function vertex(i,j) {const a=i/segments*arc,b=j/sides*TAU;return [(radius+tube*Math.cos(b))*Math.cos(a),(radius+tube*Math.cos(b))*Math.sin(a),tube*Math.sin(b),Math.cos(b)*Math.cos(a),Math.cos(b)*Math.sin(a),Math.sin(b)];}
    for(let i=0;i<segments;i++) for(let j=0;j<sides;j++) data.push(...vertex(i,j),...vertex(i+1,j),...vertex(i+1,j+1),...vertex(i,j),...vertex(i+1,j+1),...vertex(i,j+1));
    return mesh(data);
  }
  function upholsteryPiping(w,h,corner,plane,offset) {
    const data=[],points=[];
    for(let c=0;c<4;c++) for(let i=0;i<9;i++) {
      const a=c*Math.PI/2+i/8*Math.PI/2;
      const cx=(c===0||c===3?1:-1)*(w/2-corner),cy=(c<2?1:-1)*(h/2-corner);
      points.push([cx+Math.cos(a)*corner,cy+Math.sin(a)*corner]);
    }
    function vertex(i,j){
      const p=points[i%points.length],before=points[(i-1+points.length)%points.length],after=points[(i+1)%points.length];
      const tangent=normalize([after[0]-before[0],after[1]-before[1],0]);
      const a=j/6*TAU,n=[tangent[1]*Math.sin(a),-tangent[0]*Math.sin(a),Math.cos(a)];
      const xyz=[p[0]+n[0]*.012,p[1]+n[1]*.012,offset+n[2]*.012];
      return plane==='seat'?[xyz[0],xyz[2],xyz[1],n[0],n[2],n[1]]:[...xyz,...n];
    }
    for(let i=0;i<points.length;i++)for(let j=0;j<6;j++)data.push(...vertex(i,j),...vertex(i+1,j),...vertex(i+1,j+1),...vertex(i,j),...vertex(i+1,j+1),...vertex(i,j+1));
    const geometry=mesh(data);geometry.levels=[geometry,geometry,geometry,geometry];return geometry;
  }
  function part(geometry,position,rotation=[0,0,0],material=0) {return {geometry,local:compose(translation(...position),rotationZ(rotation[2]),rotationY(rotation[1]),rotationX(rotation[0])),material};}
  // Blender/Cycles passes preserve the detailed materials without shipping a 3D
  // asset loader or shading dozens of extra meshes on every animation frame.
  function makeGameCameos() {
    cameoProgram=makeProgram(`
      attribute vec2 aPosition;uniform mat4 uModel;uniform mat4 uVP;varying vec2 vUV;
      void main(){vUV=aPosition+.5;gl_Position=uVP*uModel*vec4(aPosition,0.0,1.0);}
    `,`
      precision highp float;varying vec2 vUV;
      uniform sampler2D uAtlas;uniform vec3 uAccent;
      uniform float uWire;uniform float uClay;uniform float uFinish;uniform float uOpacity;
      vec4 pass(float index){return texture2D(uAtlas,vec2((vUV.x+index)/3.0,vUV.y));}
      void main(){
        vec4 wire=pass(0.0),clay=pass(1.0),finished=pass(2.0);
        wire.rgb=mix(wire.rgb,uAccent,.4);
        wire.a*=smoothstep(vUV.y-.02,vUV.y+.02,uWire);
        float form=smoothstep(vUV.y-.025,vUV.y+.025,uClay);
        float material=smoothstep(vUV.y-.025,vUV.y+.025,uFinish);
        // Blend in premultiplied space so transparent wire pixels leave no fringe.
        vec4 w=vec4(wire.rgb*wire.a,wire.a),c=vec4(clay.rgb*clay.a,clay.a),f=vec4(finished.rgb*finished.a,finished.a);
        vec4 color=mix(w,mix(c,f,material),form);
        float scan=exp(-abs(vUV.y-uClay)*95.0)*step(.001,uClay)*(1.0-step(.999,uClay));
        scan+=exp(-abs(vUV.y-uFinish)*95.0)*step(.001,uFinish)*(1.0-step(.999,uFinish));
        color.rgb+=uAccent*scan*color.a*.4;
        gl_FragColor=color*uOpacity;
      }
    `);
    cameoLocations={p:gl.getAttribLocation(cameoProgram,'aPosition')};
    ['Model','VP','Atlas','Accent','Wire','Clay','Finish','Opacity'].forEach(n=>cameoLocations[n]=gl.getUniformLocation(cameoProgram,'u'+n));
    cameoBuffer=gl.createBuffer();gl.bindBuffer(gl.ARRAY_BUFFER,cameoBuffer);
    gl.bufferData(gl.ARRAY_BUFFER,new Float32Array([-.5,-.5,.5,-.5,-.5,.5,-.5,.5,.5,-.5,.5,.5]),gl.STATIC_DRAW);
    const definitions=[['jet',[.48,.85,1],11.3,.3],['car',[1,.67,.4],13.1,4.1],['wizard',[.77,.58,1],15.7,8.5]];
    return definitions.map(([name,accent,period,offset])=>{
      const model={name,accent,period,offset,texture:gl.createTexture(),loaded:false,aspect:1};
      let source=cameoImages.get(name);
      if(!source){source=new Image();source.decoding='async';cameoImages.set(name,source);}
      function upload(){
        if(gl.isContextLost())return;
        gl.bindTexture(gl.TEXTURE_2D,model.texture);
        gl.pixelStorei(gl.UNPACK_FLIP_Y_WEBGL,true);gl.pixelStorei(gl.UNPACK_PREMULTIPLY_ALPHA_WEBGL,false);
        gl.texImage2D(gl.TEXTURE_2D,0,gl.RGBA,gl.RGBA,gl.UNSIGNED_BYTE,source);
        gl.texParameteri(gl.TEXTURE_2D,gl.TEXTURE_MIN_FILTER,gl.LINEAR);gl.texParameteri(gl.TEXTURE_2D,gl.TEXTURE_MAG_FILTER,gl.LINEAR);
        gl.texParameteri(gl.TEXTURE_2D,gl.TEXTURE_WRAP_S,gl.CLAMP_TO_EDGE);gl.texParameteri(gl.TEXTURE_2D,gl.TEXTURE_WRAP_T,gl.CLAMP_TO_EDGE);
        model.aspect=source.naturalWidth/(source.naturalHeight*3);model.loaded=true;draw();
      }
      if(source.complete && source.naturalWidth)upload();
      else {
        source.addEventListener('load',()=>{if(gameCameos.includes(model))upload();},{once:true});
        source.addEventListener('error',()=>console.warn('Giga Couch world render unavailable:',name),{once:true});
        if(!source.src)source.src='/landing-worlds/'+name+'.png';
      }
      return model;
    });
  }
  function makeScene() {
    program=makeProgram(`
      attribute vec3 aPosition;attribute vec3 aNormal;
      uniform mat4 uModel;uniform mat4 uScanModel;uniform mat4 uVP;varying vec3 vNormal;varying vec3 vPosition;varying vec3 vLocalPosition;varying vec3 vLocalNormal;varying vec3 vScanPosition;
      void main(){vec4 p=uModel*vec4(aPosition,1.0);vPosition=p.xyz;vScanPosition=(uScanModel*vec4(aPosition,1.0)).xyz;vLocalPosition=aPosition;vLocalNormal=aNormal;vNormal=normalize(mat3(uModel)*aNormal);gl_Position=uVP*p;}
    `,`
      precision highp float;varying vec3 vNormal;varying vec3 vPosition;varying vec3 vLocalPosition;varying vec3 vLocalNormal;varying vec3 vScanPosition;
      uniform mat4 uModel;
      uniform vec3 uColor;uniform vec3 uAccent;uniform vec3 uEye;uniform float uEmission;uniform float uMetal;uniform float uOpacity;uniform float uRevealPlane;uniform float uBuilding;uniform float uQuality;
      float yarn(vec2 uv){
        float warp=sin(uv.x*410.0+sin(uv.y*23.0)*.35);
        float weft=sin(uv.y*440.0+sin(uv.x*19.0)*.35);
        float interlace=warp*weft;
        float slub=sin(uv.x*91.0+uv.y*37.0)*sin(uv.y*73.0)*.25;
        return interlace*.6+warp*.2+weft*.2+slub;
      }
      void main(){
        float frontier=vScanPosition.y-uRevealPlane;
        float cell=fract(sin(dot(floor(vScanPosition*45.0),vec3(12.9898,78.233,37.719)))*43758.5453);
        if(uBuilding>.5 && frontier>(cell-.5)*.065)discard;
        if(uBuilding<-.5 && frontier<(cell-.5)*.065)discard;
        float detail=step(2.5,uQuality)*(1.0-step(.5,uMetal));
        vec3 p=vLocalPosition;
        vec3 grain=vec3(sin(p.y*440.0+p.z*410.0),sin(p.x*410.0+p.z*440.0),sin(p.x*440.0+p.y*410.0));
        vec3 n=normalize(vNormal+mat3(uModel)*grain*.065*detail);vec3 v=normalize(uEye-vPosition);
        vec3 l1=normalize(vec3(-3.0,7.0,5.0)-vPosition),l2=normalize(vec3(5.0,3.0,-2.0)-vPosition);
        float diffuse=max(dot(n,l1),0.0)*.65+max(dot(n,l2),0.0)*.35;
        float spec=pow(max(dot(n,normalize(l1+v)),0.0),mix(30.0,95.0,uMetal));
        float edge=pow(1.0-max(dot(n,v),0.0),2.5);
        float weave=sin(vPosition.x*260.0)*sin(vPosition.y*260.0)*sin(vPosition.z*260.0)*.014;
        float threads=(sin(vPosition.x*360.0)*sin(vPosition.z*340.0)+sin(vPosition.y*310.0))*.018*detail;
        float fleck=fract(sin(dot(floor(vPosition*400.0),vec3(12.9898,78.233,37.719)))*43758.5453)*.025*detail;
        vec3 col=uColor*(.21+diffuse+threads+fleck)+vec3(.78,.93,.85)*spec*mix(.7,.16,detail)+uAccent*edge*mix(.48,.2,detail)+weave;
        col+=uAccent*pow(max(dot(n,l2),0.0),3.0)*.3;
        // Sage green linen: triplanar yarn stays attached to the moving geometry.
        // Broad, weak highlights and diffuse bounce replace the plastic sheen.
        vec3 weights=pow(abs(vLocalNormal),vec3(5.0));weights/=max(dot(weights,vec3(1.0)),.001);
        float weaveCloth=yarn(p.yz)*weights.x+yarn(p.xz)*weights.y+yarn(p.xy)*weights.z;
        float fibers=fract(sin(dot(floor(p*620.0),vec3(12.9898,78.233,37.719)))*43758.5453);
        float variation=sin(p.x*7.0+p.z*6.0)*sin(p.y*9.0+p.z*4.0)*.018;
        vec3 linen=uColor*(.96+weaveCloth*.115+(fibers-.5)*.065+variation);
        float key=max(dot(n,l1),0.0),fill=max(dot(n,l2),0.0);
        vec3 cloth=linen*(vec3(.21,.225,.23)+vec3(1.0,.94,.82)*key*.78+vec3(.63,.75,.82)*fill*.22);
        cloth+=vec3(1.0,.96,.88)*pow(max(dot(n,normalize(l1+v)),0.0),9.0)*.025;
        cloth+=uAccent*edge*.035;
        col=mix(col,cloth,detail);
        col=mix(col,uAccent*(.65+uEmission*.4),min(uEmission,1.0));
        float scan=exp(-abs(frontier)*36.0)*abs(uBuilding);
        col+=uAccent*scan*1.5;
        gl_FragColor=vec4(col,uOpacity);
      }
    `);
    locations={p:gl.getAttribLocation(program,'aPosition'),n:gl.getAttribLocation(program,'aNormal')};
    ['Model','ScanModel','VP','Color','Accent','Eye','Emission','Metal','Opacity','RevealPlane','Building','Quality'].forEach(n=>locations[n]=gl.getUniformLocation(program,'u'+n));
    starsProgram=makeProgram(`
      attribute vec4 aStar;uniform mat4 uVP;uniform float uTime;uniform float uWarp;uniform float uPixel;varying float vAlpha;
      void main(){vec3 p=aStar.xyz;float z=mod(p.z+uTime*.13+uWarp*3.0+15.0,30.0)-15.0;p.z=z;p.xy*=1.0+uWarp*.22;
      vec4 clip=uVP*vec4(p,1.0);gl_Position=clip;gl_PointSize=clamp(aStar.w*uPixel*(16.0/max(clip.w,1.0)),1.0,9.0);vAlpha=(.3+.4*sin(uTime*.6+p.x+p.z))*.6+.35;}
    `,`precision mediump float;uniform vec3 uAccent;varying float vAlpha;void main(){float d=length(gl_PointCoord-.5);float alpha=smoothstep(.5,.05,d)*vAlpha;gl_FragColor=vec4(mix(uAccent,vec3(1.0),.3),alpha);}`);
    starLocations={p:gl.getAttribLocation(starsProgram,'aStar')};['VP','Time','Warp','Pixel','Accent'].forEach(n=>starLocations[n]=gl.getUniformLocation(starsProgram,'u'+n));
    linesProgram=makeProgram(`attribute vec3 aPosition;uniform mat4 uVP;uniform mat4 uModel;void main(){gl_Position=uVP*uModel*vec4(aPosition,1.0);}`,`precision mediump float;uniform vec4 uColor;void main(){gl_FragColor=uColor;}`);
    lineLocations={p:gl.getAttribLocation(linesProgram,'aPosition')};['VP','Model','Color'].forEach(n=>lineLocations[n]=gl.getUniformLocation(linesProgram,'u'+n));
    wireProgram=makeProgram(`
      attribute vec3 aPosition;uniform mat4 uVP;uniform mat4 uModel;uniform mat4 uScanModel;varying vec3 vPosition;
      void main(){vec4 p=uModel*vec4(aPosition,1.0);vPosition=(uScanModel*vec4(aPosition,1.0)).xyz;gl_Position=uVP*p;}
    `,`
      precision highp float;varying vec3 vPosition;uniform vec3 uAccent;uniform float uRevealPlane;uniform float uTime;uniform float uWireMode;uniform float uWireFade;
      void main(){
        float d=vPosition.y-uRevealPlane;
        float skeleton=uWireMode>.5?smoothstep(-.025,.055,d):1.0-smoothstep(-.025,.055,d);
        float scan=exp(-abs(d)*20.0);
        float pulse=.78+.22*sin(vPosition.y*8.0+uTime*2.0);
        float alpha=(skeleton*.72*pulse+scan*.8)*uWireFade;
        gl_FragColor=vec4(mix(uAccent,vec3(1.0),.15)*(1.0+scan*.5),alpha);
      }
    `);
    wireLocations={p:gl.getAttribLocation(wireProgram,'aPosition')};
    ['VP','Model','ScanModel','Accent','RevealPlane','Time','WireMode','WireFade'].forEach(n=>wireLocations[n]=gl.getUniformLocation(wireProgram,'u'+n));
    const base=roundBox(4.9,.57,2.03,.24), back=roundBox(4.83,1.7,.5,.23),arm=roundBox(.58,1.24,2.2,.27),seat=roundBox(1.97,.39,1.62,.18),pillow=roundBox(1.9,1.14,.38,.18),leg=roundBox(.14,.46,.14,.04,4),trim=roundBox(4.55,.035,1.85,.015,3);
    couchParts=[part(base,[0,-.25,0]),part(back,[0,.62,-.81],[-.08,0,0]),part(arm,[-2.22,.12,.02]),part(arm,[2.22,.12,.02]),part(seat,[-1.015,.13,.12]),part(seat,[1.015,.13,.12]),part(pillow,[-1.015,.75,-.44],[-.18,0,0]),part(pillow,[1.015,.75,-.44],[-.18,0,0]),part(trim,[0,-.47,0],[0,0,0],2)];
    for(const x of [-1.98,1.98]) for(const z of [-.63,.68]) couchParts.push(part(leg,[x,-.68,z],[0,0,x<0?.1:-.1],1));
    // Four actual geometry levels: hard blocks, faceted bevels, smooth surfaces,
    // and inflated cushions. Each refinement is revealed by the next scan pass.
    for(const geometry of new Set(couchParts.map(p=>p.geometry))) {
      const [w,h,d,r]=geometry.shape;
      geometry.levels=[
        roundBox(w,h,d,Math.min(r*.12,.02),1,true),
        roundBox(w,h,d,r*.85,4,true),
        geometry,
        roundBox(w,h,d,r,16,false,w>1 && w<2.1 && h>.25?.105:0)
      ];
    }
    const seatPiping=upholsteryPiping(1.85,1.48,.18,'seat',.14);
    const backPiping=upholsteryPiping(1.72,.97,.17,'back',.16);
    for(const x of [-1.015,1.015]){
      couchParts.push(part(seatPiping,[x,.13,.12],[0,0,0],3));
      couchParts.push(part(backPiping,[x,.75,-.44],[-.18,0,0],3));
    }
    ringMeshes=[torus(3.4,.017),torus(3.49,.005),torus(3.64,.008,100,5,Math.PI*1.35),torus(3.72,.005,70,4,Math.PI*.75),torus(3.4,.09),torus(3.4,.19),torus(3.4,.36)];
    const body=roundBox(.93,.21,.58,.1,8),handle=roundBox(.26,.25,.57,.12,7),stick=torus(.09,.028,20,6),face=roundBox(.064,.025,.064,.023,5),dpad=roundBox(.23,.03,.065,.02,4);
    controllerParts=[part(body,[0,0,0],[0,0,0],1),part(handle,[-.36,-.01,.21],[0,0,.18],1),part(handle,[.36,-.01,.21],[0,0,-.18],1),part(stick,[-.2,.14,.11],[-Math.PI/2,0,0],0),part(stick,[.14,.14,.14],[-Math.PI/2,0,0],0),part(dpad,[-.27,.12,-.1],[0,0,0],2),part(dpad,[-.27,.12,-.1],[0,Math.PI/2,0],2)];
    for(const [x,z] of [[.25,-.2],[.35,-.1],[.15,-.1],[.25,0]]) controllerParts.push(part(face,[x,.125,z],[0,0,0],2));
    const stars=[];let seed=187;const random=()=>{seed=(seed*16807)%2147483647;return (seed-1)/2147483646;};
    for(let i=0;i<600;i++) stars.push((random()-.5)*45,(random()-.5)*24,(random()-.5)*30,.6+random()*1.8);
    starBuffer=gl.createBuffer();gl.bindBuffer(gl.ARRAY_BUFFER,starBuffer);gl.bufferData(gl.ARRAY_BUFFER,new Float32Array(stars),gl.STATIC_DRAW);
    const orbit=[];
    for(let i=0;i<96;i++){const a=i/96*TAU;const r=i%4===0?3.89:3.82;orbit.push(Math.cos(a)*3.75,Math.sin(a)*3.75,0,Math.cos(a)*r,Math.sin(a)*r,0);}
    orbitBuffer={buffer:gl.createBuffer(),count:orbit.length/3};gl.bindBuffer(gl.ARRAY_BUFFER,orbitBuffer.buffer);gl.bufferData(gl.ARRAY_BUFFER,new Float32Array(orbit),gl.STATIC_DRAW);
    const dust=[];for(let i=0;i<64;i++){const a=i/64*TAU;dust.push(Math.cos(a)*3.47,Math.sin(a)*3.47,0,Math.cos(a+.006)*3.47,Math.sin(a+.006)*3.47,0);}
    dustBuffer={buffer:gl.createBuffer(),count:dust.length/3};gl.bindBuffer(gl.ARRAY_BUFFER,dustBuffer.buffer);gl.bufferData(gl.ARRAY_BUFFER,new Float32Array(dust),gl.STATIC_DRAW);
    gameCameos=makeGameCameos();
    gl.enable(gl.DEPTH_TEST);gl.depthFunc(gl.LEQUAL);ready=true;document.body.classList.add('scene-ready');
  }
  function renderMesh(geometry,model,color,emission=0,metal=0,opacity=1,building=0,quality=2,scanModel=model) {
    gl.useProgram(program);gl.bindBuffer(gl.ARRAY_BUFFER,geometry.buffer);gl.enableVertexAttribArray(locations.p);gl.enableVertexAttribArray(locations.n);gl.vertexAttribPointer(locations.p,3,gl.FLOAT,false,24,0);gl.vertexAttribPointer(locations.n,3,gl.FLOAT,false,24,12);
    gl.uniformMatrix4fv(locations.Model,false,model);gl.uniformMatrix4fv(locations.ScanModel,false,scanModel);gl.uniform3fv(locations.Color,color);gl.uniform1f(locations.Emission,emission);gl.uniform1f(locations.Metal,metal);gl.uniform1f(locations.Opacity,opacity);gl.uniform1f(locations.Building,building);gl.uniform1f(locations.Quality,quality);gl.drawArrays(gl.TRIANGLES,0,geometry.count);
    gl.disableVertexAttribArray(locations.n);gl.disableVertexAttribArray(locations.p);
  }
  function renderLines(geometry,model,vp,alpha) {
    gl.useProgram(linesProgram);gl.bindBuffer(gl.ARRAY_BUFFER,geometry.buffer);gl.enableVertexAttribArray(lineLocations.p);gl.vertexAttribPointer(lineLocations.p,3,gl.FLOAT,false,12,0);gl.uniformMatrix4fv(lineLocations.VP,false,vp);gl.uniformMatrix4fv(lineLocations.Model,false,model);gl.uniform4f(lineLocations.Color,...currentColor,alpha);gl.drawArrays(gl.LINES,0,geometry.count);gl.disableVertexAttribArray(lineLocations.p);
  }
  function renderWire(geometry,model,vp,plane,mode=1,fade=1,scanModel=model,accent=currentColor) {
    if(!geometry.wireBuffer)return;
    gl.useProgram(wireProgram);gl.bindBuffer(gl.ARRAY_BUFFER,geometry.wireBuffer);
    gl.enableVertexAttribArray(wireLocations.p);gl.vertexAttribPointer(wireLocations.p,3,gl.FLOAT,false,12,0);
    gl.uniformMatrix4fv(wireLocations.VP,false,vp);gl.uniformMatrix4fv(wireLocations.Model,false,model);gl.uniformMatrix4fv(wireLocations.ScanModel,false,scanModel);
    gl.uniform3fv(wireLocations.Accent,accent);gl.uniform1f(wireLocations.RevealPlane,plane);gl.uniform1f(wireLocations.Time,time);gl.uniform1f(wireLocations.WireMode,mode);gl.uniform1f(wireLocations.WireFade,fade);
    gl.drawArrays(gl.LINES,0,geometry.wireCount);gl.disableVertexAttribArray(wireLocations.p);
  }
  const ease=n=>{n=Math.max(0,Math.min(1,n));return n*n*(3-2*n);};
  function cameoState(index,t,mobile,still=false) {
    const model=gameCameos[index];
    // Portrait layouts give each object its own eight-second visit.
    if(mobile && (still?index!==0:Math.floor(t/8)%3!==index))return null;
    const age=still?3.6:mobile?t%8:(t+model.offset)%model.period;
    if(age>=7.4)return null;
    const entry=ease(age/.65),exit=ease((age-5.5)/1.9);
    return {age,entry,exit,opacity:entry*(1-exit),build:ease((age-.85)/1.0),wire:ease(age/.8)};
  }
  function renderCameos() {
    const mobile=width<760,compact=width<1100,span=32*Math.tan(.325);
    const vp=compose(perspective(.65,width/height,.1,60),translation(0,0,-16));
    const anchors=mobile?[[.5,.405],[.5,.415],[.5,.415]]:compact?[[.12,.505],[.86,.735],[.90,.475]]:[[.115,.375],[.865,.735],[.89,.415]];
    gl.useProgram(cameoProgram);gl.bindBuffer(gl.ARRAY_BUFFER,cameoBuffer);
    gl.enableVertexAttribArray(cameoLocations.p);gl.vertexAttribPointer(cameoLocations.p,2,gl.FLOAT,false,0,0);
    gl.uniformMatrix4fv(cameoLocations.VP,false,vp);gl.uniform1i(cameoLocations.Atlas,0);
    gl.disable(gl.DEPTH_TEST);gl.enable(gl.BLEND);gl.blendFunc(gl.ONE,gl.ONE_MINUS_SRC_ALPHA);
    for(let index=0;index<gameCameos.length;index++) {
      const model=gameCameos[index],state=cameoState(index,time,mobile,reduced.matches);
      if(!model.loaded || !state || state.opacity<.005)continue;
      const {age,entry,exit,opacity}=state;
      let [x,y]=anchors[index],rz=0;
      if(index===0){x-=(1-entry)*.17+exit*.19;x+=(age/7.4-.5)*.035;y-=exit*.18;rz=Math.sin(age*.9)*.05+exit*1.5;}
      if(index===1){x+=(entry-1)*.05+exit*.2+(age/7.4-.5)*.05;y+=Math.sin(age*2)*.0015;rz=-.025+exit*.07;}
      if(index===2){y+=(1-entry)*.025-exit*.07+Math.sin(age*1.7)*.006;rz=Math.sin(age)*.015;}
      const pixels=index===2?(mobile?128:compact?166:240):(mobile?136:compact?160:index===0?260:245);
      const w=index===2?pixels*model.aspect:pixels,h=index===2?pixels:pixels/model.aspect;
      const root=compose(translation((x-.5)*span*width/height,(.5-y)*span,0),rotationZ(rz),scale(w*span/height,h*span/height,1));
      gl.uniformMatrix4fv(cameoLocations.Model,false,root);gl.uniform3fv(cameoLocations.Accent,model.accent);
      gl.uniform1f(cameoLocations.Wire,ease(age/.65));gl.uniform1f(cameoLocations.Clay,ease((age-.7)/.55));
      gl.uniform1f(cameoLocations.Finish,ease((age-1.25)/.65));gl.uniform1f(cameoLocations.Opacity,opacity);
      gl.activeTexture(gl.TEXTURE0);gl.bindTexture(gl.TEXTURE_2D,model.texture);gl.drawArrays(gl.TRIANGLES,0,6);
    }
    gl.disableVertexAttribArray(cameoLocations.p);gl.disable(gl.BLEND);gl.enable(gl.DEPTH_TEST);
    // The interactive couch remains in front of the decorative worlds.
    gl.clear(gl.DEPTH_BUFFER_BIT);
  }
  // A 28-second creation story. Every new pass replaces only the scanned region,
  // so viewers can see blocky and refined geometry side by side at the frontier.
  function creationState(t) {
    const c=t%28,smooth=n=>{n=Math.max(0,Math.min(1,n));return n*n*(3-2*n);};
    if(c<4.5)return {previous:-1,next:-1,progress:smooth((c-.5)/3),label:'01 / THE IDEA',wireMode:0,wireFade:1};
    if(c<8)return {previous:-1,next:0,progress:smooth((c-4.5)/2.8),label:'02 / BLOCKING IT OUT',wireMode:1,wireFade:1};
    if(c<11.5)return {previous:0,next:1,progress:smooth((c-8)/2.8),label:'03 / FINDING THE FORM'};
    if(c<15)return {previous:1,next:2,progress:smooth((c-11.5)/2.8),label:'04 / SMOOTHING THE EDGES'};
    if(c<23.5)return {previous:2,next:3,progress:smooth((c-15)/3.7),label:c<18.7?'05 / THE FINISHING TOUCH':'06 / IMAGINATION, MADE REAL'};
    if(c<27)return {previous:-1,next:3,progress:1-smooth((c-23.5)/3.5),label:'BACK TO THE SPARK',wireMode:1,wireFade:1};
    return {previous:-1,next:-1,progress:1,label:'DREAM IT ALL AGAIN',wireMode:0,wireFade:1-smooth(c-27)};
  }
  // A separate, capped-resolution layer puts the world behind the typography.
  // One shared clock drives both canvases, including pause and reduced motion.
  function makeBackdrop() {
    const surface=$('#dimension-field');
    const context=surface.getContext('webgl',{alpha:false,antialias:false,powerPreference:'low-power'});
    if(!context)return null;
    function compile(type,source) {
      const shader=context.createShader(type);
      context.shaderSource(shader,source);context.compileShader(shader);
      if(!context.getShaderParameter(shader,context.COMPILE_STATUS))throw new Error(context.getShaderInfoLog(shader));
      return shader;
    }
    const vertex=compile(context.VERTEX_SHADER,`
      attribute vec2 aPosition;
      varying vec2 vUV;
      void main(){vUV=aPosition*.5+.5;gl_Position=vec4(aPosition,0.0,1.0);}
    `);
    const fragment=compile(context.FRAGMENT_SHADER,`
      precision highp float;
      varying vec2 vUV;
      uniform vec2 uSize;uniform vec2 uPointer;uniform vec3 uAccent;
      uniform float uTime;uniform float uWarpAge;uniform float uScanAge;uniform float uFinish;
      float hash(vec2 p){return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453);}
      float noise(vec2 p){
        vec2 i=floor(p),f=fract(p);f=f*f*(3.0-2.0*f);
        return mix(mix(hash(i),hash(i+vec2(1.0,0.0)),f.x),mix(hash(i+vec2(0.0,1.0)),hash(i+vec2(1.0)),f.x),f.y);
      }
      float mist(vec2 p){
        float value=0.0,weight=.55;
        for(int i=0;i<4;i++){value+=noise(p)*weight;p=mat2(1.7,1.2,-1.2,1.7)*p+3.1;weight*=.48;}
        return value;
      }
      void main(){
        float aspect=uSize.x/uSize.y,t=uTime;
        vec2 p=(vUV-.5)*vec2(aspect,1.0);
        p-=vec2(uPointer.x*.025,-uPointer.y*.015);
        vec2 center=vec2(0.0,-.07),q=p-center;
        float radius=length(q),warp=sin(clamp(uWarpAge/2.2,0.0,1.0)*3.141593);
        // A traveling gravity wave bends the aurora and the lattice together.
        float shock=exp(-pow((radius-uWarpAge*.65)*16.0,2.0))*warp;
        p+=normalize(q+vec2(.0001))*(shock*.035+warp*.025);
        vec3 cool=mix(vec3(.10,.48,.51),uAccent.bgr*.5,.35);
        vec3 color=vec3(.012,.025,.032);
        vec2 flow=p*2.3+vec2(t*.022,-t*.014);
        float cloud=mist(flow+vec2(mist(flow+4.0),mist(flow-3.0))*.95);
        float veil=pow(cloud,3.0);
        float banks=exp(-length((p-vec2(-.55,.05))*vec2(1.3,2.7))*2.0)+exp(-length((p-vec2(.62,-.12))*vec2(1.7,3.0))*2.0);
        color+=mix(cool,uAccent,smoothstep(-.5,.6,p.x)) * veil*(.38+banks*.62);
        color+=uAccent*exp(-length(q*vec2(1.0,1.45))*3.7)*(.035+uFinish*.035);
        // Layered aurora silk: bright, narrow filaments inside broad soft folds.
        float ribbons=0.0,halo=0.0;
        for(int i=0;i<7;i++){
          float layer=float(i),x=p.x+layer*.08;
          float curve=.13+sin(x*2.8+t*.12+layer*.16)*.22+sin(x*5.1-t*.08)*.04;
          curve+=(layer-3.0)*.018;
          curve+=uPointer.y*exp(-pow(x-uPointer.x*aspect*.4,2.0)*4.0)*.07;
          float d=abs(p.y-curve);
          float taper=.4+.6*pow(sin(x*1.2+layer*.5+t*.09),2.0);
          ribbons+=exp(-d*(310.0+layer*25.0))*taper;
          halo+=exp(-d*24.0)*taper;
        }
        // The center stays dark enough for the headline and couch silhouette.
        float sides=smoothstep(.12,.65,abs(p.x));
        float silkMask=mix(.2,1.0,sides);
        color+=mix(cool,uAccent,.75)*(ribbons*.24+halo*.027)*silkMask;
        // Perspective floor: the grid travels through an infinite, rolling world.
        float horizon=-.10+sin(p.x*3.0+t*.1)*.014;
        float floorY=horizon-p.y;
        if(floorY>.002){
          float depth=.42/max(floorY,.012);
          vec2 ground=vec2(p.x*depth,depth+t*.23+warp*2.0);
          ground.x+=sin(ground.y*.25+t*.12)*.35;
          vec2 cell=abs(fract(ground*.62-.5)-.5);
          float lineWidth=clamp(depth*depth/uSize.y*.65,.004,.07);
          float grid=1.0-smoothstep(lineWidth,lineWidth*2.3,min(cell.x,cell.y));
          float fade=exp(-depth*.075)*smoothstep(.0,.065,floorY);
          float wave=exp(-pow((length(vec2(ground.x,(depth-4.0)*.65))-uScanAge*4.0)*1.2,2.0));
          wave*=1.0-smoothstep(1.2,2.6,uScanAge);
          color+=uAccent*(grid*(.055+wave*.25)+wave*.025)*fade;
          color+=cool*exp(-floorY*23.0)*.09;
        }
        // Distant stars have depth and drift; portal jumps stretch them into rays.
        for(int i=0;i<3;i++){
          float layer=float(i),density=48.0+layer*25.0;
          vec2 sky=p*vec2(1.0,1.0+warp*2.0)+uPointer*.008*layer+vec2(t*.001*(layer+1.0),0.0);
          vec2 cell=floor(sky*density),local=fract(sky*density)-.5;
          float seed=hash(cell+layer*57.0);
          float star=1.0-smoothstep(.012,.05+layer*.018,length(local));
          star*=step(.965,seed)*(.5+.5*sin(t*.4+seed*90.0));
          color+=mix(uAccent,vec3(1.0),.6)*star*(.18+layer*.1);
        }
        // Radial flight trails only emerge while opening another dimension.
        float angle=atan(q.y,q.x);
        float ray=pow(max(0.0,sin(angle*91.0+noise(vec2(angle*8.0,1.0))*8.0)),28.0);
        float streak=pow(max(0.0,sin(radius*27.0-t*14.0+angle*9.0)),7.0);
        color+=uAccent*(ray*streak*.65+shock*.2)*warp*smoothstep(.2,.65,radius);
        // Leave calm pockets behind the navigation and bottom copy.
        color*=1.0-smoothstep(.30,.5,p.y)*.62;
        color*=1.0-smoothstep(.30,.50,abs(p.x))*smoothstep(.17,.42,-p.y)*.55;
        color*=1.0-smoothstep(.72,1.15,length((vUV-.5)*vec2(1.0,1.25)))*.5;
        color+=(hash(gl_FragCoord.xy)-.5)/255.0;
        gl_FragColor=vec4(color,1.0);
      }
    `);
    const backdropProgram=context.createProgram();
    context.attachShader(backdropProgram,vertex);context.attachShader(backdropProgram,fragment);context.linkProgram(backdropProgram);
    context.deleteShader(vertex);context.deleteShader(fragment);
    if(!context.getProgramParameter(backdropProgram,context.LINK_STATUS))throw new Error(context.getProgramInfoLog(backdropProgram));
    const buffer=context.createBuffer();context.bindBuffer(context.ARRAY_BUFFER,buffer);
    context.bufferData(context.ARRAY_BUFFER,new Float32Array([-1,-1,1,-1,-1,1,-1,1,1,-1,1,1]),context.STATIC_DRAW);
    context.useProgram(backdropProgram);
    const position=context.getAttribLocation(backdropProgram,'aPosition');
    context.enableVertexAttribArray(position);context.vertexAttribPointer(position,2,context.FLOAT,false,0,0);
    const uniforms={};['Size','Pointer','Accent','Time','WarpAge','ScanAge','Finish'].forEach(n=>uniforms[n]=context.getUniformLocation(backdropProgram,'u'+n));
    let lastTime=-1,lastColor='',valid=true;
    document.body.classList.add('backdrop-ready');
    return {
      resize(){
        const ratio=Math.min(devicePixelRatio||1,1,1100/width);
        surface.width=Math.round(width*ratio);surface.height=Math.round(height*ratio);
        context.viewport(0,0,surface.width,surface.height);lastTime=-1;
      },
      render(){
        if(!valid || context.isContextLost())return;
        const color=currentColor.join(',');
        if(lastTime>=0 && (paused?time===lastTime && color===lastColor:Math.abs(time-lastTime)<1/30))return;
        lastTime=time;lastColor=color;
        const cycle=time%28,beats=[0,4.5,8,11.5,15,18.7,23.5];
        const beat=beats.reduce((previous,n)=>cycle>=n?n:previous,0);
        context.uniform2f(uniforms.Size,surface.width,surface.height);
        context.uniform2f(uniforms.Pointer,smoothX,smoothY);
        context.uniform3fv(uniforms.Accent,currentColor);
        context.uniform1f(uniforms.Time,time);
        const portalAge=time<2.2 && warpStart<0?time:Math.max(-1,time-warpStart);
        context.uniform1f(uniforms.WarpAge,reduced.matches?-1:portalAge);
        context.uniform1f(uniforms.ScanAge,reduced.matches?10:cycle-beat);
        context.uniform1f(uniforms.Finish,reduced.matches?1:Math.max(0,Math.min(1,(cycle-15)/3.7)));
        context.drawArrays(context.TRIANGLES,0,6);
      },
      invalidate(){valid=false;}
    };
  }
  function restoreBackdrop() {
    try {backdrop=makeBackdrop();if(backdrop){backdrop.resize();backdrop.render();}}
    catch(error){backdrop=null;document.body.classList.remove('backdrop-ready');console.warn('Giga Couch background unavailable:',error);}
  }
  $('#dimension-field').addEventListener('webglcontextlost',e=>{e.preventDefault();backdrop?.invalidate();document.body.classList.remove('backdrop-ready');});
  $('#dimension-field').addEventListener('webglcontextrestored',restoreBackdrop);
  function resize() {
    const r=canvas.getBoundingClientRect(),dpr=Math.min(devicePixelRatio||1,1.75);
    width=r.width;height=r.height;canvas.width=Math.round(width*dpr);canvas.height=Math.round(height*dpr);
    if(gl)gl.viewport(0,0,canvas.width,canvas.height);backdrop?.resize();draw();updateScroll();
  }
  function draw() {
    if(!ready || !width || !height) return;
    const mobile=width<760,aspect=width/height;
    const warpAge=time-warpStart,warp=paused?0:Math.max(0,1-warpAge/1.6);
    for(let i=0;i<3;i++){currentColor[i]+=(palettes[dimension].rgb[i]-currentColor[i])*(paused?1:.04);currentCouch[i]+=(palettes[dimension].couch[i]-currentCouch[i])*(paused?1:.04);}
    backdrop?.render();
    const eye=[smoothX*.65,3.8+smoothY*.4,mobile?16.8:12.6];
    const fov=mobile?.70:.65;
    const view=lookAt(eye,[0,mobile?1.85:.75,0]);
    // A portrait view uses a smaller scene so the portal stays inside the screen.
    const sceneScale=mobile?Math.min(.86,aspect*1.7):1;
    const vp=multiply(perspective(fov,aspect,.1,80),view);
    gl.clearColor(0,0,0,0);gl.clear(gl.COLOR_BUFFER_BIT|gl.DEPTH_BUFFER_BIT);
    gl.useProgram(program);gl.uniformMatrix4fv(locations.VP,false,vp);gl.uniform3fv(locations.Accent,currentColor);gl.uniform3fv(locations.Eye,eye);
    const bob=Math.sin(time*.8)*.17;
    const root=compose(translation(0,mobile?.28:-.65,0),scale(sceneScale),rotationY(-.2+smoothX*.18+Math.sin(time*.17)*.05),rotationZ(-.09+smoothY*.025));
    const couch=compose(root,translation(0,bob,0),orbitMatrix(),rotationY(Math.sin(time*.35)*.12));
    const stage=reduced.matches?{previous:3,next:3,progress:1,label:'IMAGINATION, MADE REAL'}:creationState(time);
    // Scan in couch space so every pass stays aligned at any viewing angle.
    const plane=-1.3+stage.progress*3.2;
    gl.uniform1f(locations.RevealPlane,plane);
    const label=$('#build-phase');
    if(label && label.textContent!==stage.label)label.textContent=stage.label;
    // Portal sits behind the furniture. Extra rings layer light without postprocessing.
    const ring=compose(root,translation(0,.35,-1.35),rotationX(-.16),rotationY(.08));
    renderMesh(ringMeshes[0],ring,currentColor,1);
    renderMesh(ringMeshes[1],ring,currentColor,.65);
    renderMesh(ringMeshes[2],multiply(ring,rotationZ(-time*.07)),currentColor,.7);
    renderMesh(ringMeshes[3],multiply(ring,rotationZ(time*.05+2)),currentColor,.4);
    // The orbit's smaller ticks move independently, like a living instrument.
    gl.enable(gl.BLEND);gl.blendFuncSeparate(gl.SRC_ALPHA,gl.ONE,gl.ONE,gl.ONE);gl.depthMask(false);
    renderMesh(ringMeshes[4],ring,currentColor,1,0,.055);
    renderMesh(ringMeshes[5],ring,currentColor,1,0,.025);
    renderMesh(ringMeshes[6],ring,currentColor,1,0,.008);
    renderLines(orbitBuffer,multiply(ring,rotationZ(time*.015)),vp,.35);
    renderLines(dustBuffer,multiply(ring,rotationZ(-time*.12)),vp,.8);
    gl.depthMask(true);gl.disable(gl.BLEND);
    renderCameos();
    gl.useProgram(program);
    gl.uniformMatrix4fv(locations.VP,false,vp);gl.uniform3fv(locations.Accent,currentColor);gl.uniform3fv(locations.Eye,eye);gl.uniform1f(locations.RevealPlane,plane);
    function renderCouchQuality(quality,clip) {
      if(quality<0)return;
      couchParts.forEach((p,index)=>{
        // Tailored piping arrives only with the final upholstery pass.
        if(index>=13 && quality<3)return;
        let albedo=quality===0?currentCouch.map(n=>n*.65+.1):quality===3?[.36,.62,.43]:currentCouch;
        if(quality===3){
          const contact=index===0?.73:index===1?.81:p.material===3?.83:1;
          albedo=albedo.map(n=>n*contact);
          if(p.material===1||p.material===2)albedo=[.075,.069,.057];
        }else if(p.material===1)albedo=albedo.map(n=>n*.4);
        renderMesh(p.geometry.levels[quality],multiply(couch,p.local),albedo,p.material===2&&quality<3?.35:0,p.material===1||p.material===2?.7:0,1,clip,quality,p.local);
      });
    }
    if(stage.progress===1)renderCouchQuality(stage.next,0);
    else {
      renderCouchQuality(stage.previous,-1);
      renderCouchQuality(stage.next,1);
    }
    if(stage.wireMode!==undefined){
      gl.enable(gl.BLEND);gl.blendFuncSeparate(gl.SRC_ALPHA,gl.ONE,gl.ONE,gl.ONE);gl.depthMask(false);gl.disable(gl.DEPTH_TEST);
      couchParts.slice(0,13).forEach(p=>renderWire(p.geometry,multiply(couch,p.local),vp,plane,stage.wireMode,stage.wireFade,p.local));
      gl.enable(gl.DEPTH_TEST);gl.depthMask(true);gl.disable(gl.BLEND);
    }
    for(let c=0;c<2;c++) {
      const controller=compose(root,translation(c===0?-3.18:3.05,-.05+Math.sin(time*.8+c*3)*.22,c===0?.3:1.1),rotationY(c===0?.4:-.8),rotationX(.55),rotationZ(c===0?-.5:.5),scale(c===0?.82:.7));
      controllerParts.forEach(p=>renderMesh(p.geometry,multiply(controller,p.local),p.material===1?[.1,.14,.13]:currentColor,p.material===2?.5:0,.7));
    }
    // Additive points make a light field around the scene; no animation when offscreen.
    gl.enable(gl.BLEND);gl.blendFuncSeparate(gl.SRC_ALPHA,gl.ONE,gl.ONE,gl.ONE);gl.depthMask(false);
    gl.useProgram(starsProgram);gl.uniformMatrix4fv(starLocations.VP,false,vp);gl.uniform1f(starLocations.Time,time);gl.uniform1f(starLocations.Warp,warp*warp*9);gl.uniform1f(starLocations.Pixel,canvas.width/width);gl.uniform3fv(starLocations.Accent,currentColor);gl.bindBuffer(gl.ARRAY_BUFFER,starBuffer);gl.enableVertexAttribArray(starLocations.p);gl.vertexAttribPointer(starLocations.p,4,gl.FLOAT,false,16,0);gl.drawArrays(gl.POINTS,0,600);gl.disableVertexAttribArray(starLocations.p);
    if(warp>0){const pulse=compose(ring,scale(1+(1-warp)*2.4));renderLines(orbitBuffer,pulse,vp,warp*.9);}
    gl.depthMask(true);gl.disable(gl.BLEND);
  }
  function tick(stamp) {
    requestFrame=0;
    if(document.hidden||!onScreen||!ready){last=0;return;}
    const dt=last?Math.min((stamp-last)/1000,.05):0;last=stamp;
    if(!paused){time+=dt;smoothX+=(pointerX-smoothX)*.035;smoothY+=(pointerY-smoothY)*.035;}
    const turned=pollControllers(dt);
    // Paused/reduced-motion scenes only redraw in response to explicit input.
    if(!paused||turned)draw();
    requestFrame=requestAnimationFrame(tick);
  }
  function start(){if(!requestFrame&&!document.hidden&&onScreen&&ready)requestFrame=requestAnimationFrame(tick);}
  try {
    gl=canvas.getContext('webgl',{alpha:true,antialias:true,powerPreference:'low-power',premultipliedAlpha:true});
    if(!gl)throw new Error('WebGL unavailable');
    makeScene();resize();restoreBackdrop();
    if('ResizeObserver' in window){const ro=new ResizeObserver(resize);ro.observe(canvas);observers.push(ro);}else addEventListener('resize',resize);
    if('IntersectionObserver' in window){const io=new IntersectionObserver(entries=>{onScreen=entries[0].isIntersecting;if(onScreen)start();else{cancelAnimationFrame(requestFrame);requestFrame=0;last=0;}});io.observe(hero);observers.push(io);}
    canvas.addEventListener('webglcontextlost',e=>{e.preventDefault();ready=false;cancelAnimationFrame(requestFrame);requestFrame=0;document.body.classList.remove('scene-ready');});
    canvas.addEventListener('webglcontextrestored',()=>{couchParts=[];ringMeshes=[];controllerParts=[];makeScene();resize();start();});
  } catch (error) {
    console.warn('Giga Couch 3D preview unavailable:', error);
    ready=false;document.body.classList.remove('scene-ready');
  }
  syncMotion();
})();
