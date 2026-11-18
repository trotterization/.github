#include <metal_stdlib>
using namespace metal;

struct Params { uint width; uint height; float phase; uint padding; };

float hash21(float2 p) {
    p = fract(p * float2(123.34, 456.21));
    p += dot(p, p + 45.32);
    return fract(p.x * p.y);
}

float3 rotate(float3 p, float phase) {
    float a = 0.22 * sin(phase), b = phase;
    p.xy = float2(cos(a)*p.x-sin(a)*p.y, sin(a)*p.x+cos(a)*p.y);
    p.xz = float2(cos(b)*p.x-sin(b)*p.z, sin(b)*p.x+cos(b)*p.z);
    return p;
}

float2 field(float3 p, float phase) {
    p = rotate(p, phase);
    float4 origin=float4(p,0.13*sin(phase));
    float4 z=origin;
    float dr=1.0,r=0.0,trap=10.0;
    float power=7.5+0.5*cos(phase);
    for(int i=0;i<12;i++) {
        r=length(z);
        trap=min(trap,length(z.xy));
        if(r>3.0) break;
        float a=acos(clamp(z.x/max(r,0.00001),-1.0,1.0));
        float b=acos(clamp(z.y/max(length(z.yzw),0.00001),-1.0,1.0));
        float c=atan2(z.w,z.z);
        dr=pow(r,power-1.0)*power*dr+1.0;
        float zr=pow(r,power);
        a*=power; b*=power; c*=power;
        z=zr*float4(cos(a),sin(a)*cos(b),sin(a)*sin(b)*cos(c),sin(a)*sin(b)*sin(c))+origin;
    }
    return float2(0.5*log(max(r,1.0001))*r/dr,trap);
}

float3 normalAt(float3 p, float phase) {
    float2 e = float2(0.0015,0);
    return normalize(float3(field(p+e.xyy,phase).x-field(p-e.xyy,phase).x,
                            field(p+e.yxy,phase).x-field(p-e.yxy,phase).x,
                            field(p+e.yyx,phase).x-field(p-e.yyx,phase).x));
}

float shadowAt(float3 p, float3 light, float phase) {
    float result=1.0, t=0.008;
    for (int i=0;i<36;i++) {
        float d=field(p+light*t,phase).x;
        result=min(result,12.0*d/t);
        t+=clamp(d,0.012,0.15);
        if (result<0.01 || t>3.5) break;
    }
    return clamp(result,0.03,1.0);
}

float3 stars(float2 uv, float phase) {
    float3 color = float3(0.0003,0.0004,0.0015);
    for (int layer=0; layer<3; layer++) {
        float scale = 100.0 + 95.0*layer;
        float2 grid = uv*scale;
        float2 id = floor(grid), cell = fract(grid)-0.5;
        float h = hash21(id+float(layer)*21.0);
        float2 offset = float2(hash21(id+11.0),hash21(id+47.0)) * 0.7 - 0.35;
        float d = length(cell-offset);
        float twinkle = 0.7 + 0.3*sin(phase+6.283*h);
        float star = exp(-d*d*800.0)*step(0.987,h)*twinkle;
        color += mix(float3(0.40,0.48,1.0), float3(1.0,0.72,0.51), h)*star*(0.3+0.15*layer);
    }
    return color;
}

kernel void render(device uchar4 *pixels [[buffer(0)]], constant Params &params [[buffer(1)]],
                   uint2 gid [[thread_position_in_grid]]) {
    if (gid.x >= params.width || gid.y >= params.height) return;
    float2 uv = (float2(gid)+0.5-float2(params.width,params.height)*0.5)/float(params.height);
    float phase=params.phase;
    float3 ro=float3(0,0.1,5.2);
    float3 rd=normalize(float3(uv.x, -uv.y+0.05, -1.85));
    float3 color=stars(uv,phase);
    float t=1.0;
    float glow=0;
    float2 info;
    bool hit=false;
    for (int step=0; step<165; step++) {
        float3 p=ro+t*rd;
        info=field(p,phase);
        glow+=exp(-info.x*100.0)*0.0018;
        if (info.x<0.00055*t) { hit=true; break; }
        t+=max(info.x*0.68,0.0003);
        if (t>8.8) break;
    }
    if (hit) {
        float3 p=ro+t*rd;
        float3 n=normalAt(p,phase);
        float3 key=normalize(float3(-3.0,3.0,4.0));
        float3 fill=normalize(float3(3.0,-1.0,1.0));
        float d=max(dot(n,key),0.0);
        float d2=max(dot(n,fill),0.0);
        float fresnel=pow(1.0-max(dot(n,-rd),0.0),2.8);
        float spec=pow(max(dot(reflect(-key,n),-rd),0.0),60.0);
        float shadow=shadowAt(p+n*0.006,key,phase);
        float ao=1.0;
        for(int j=1;j<=4;j++) {
            float h=0.016*float(j*j);
            ao-=max(0.0,h-field(p+n*h,phase).x)*0.85/float(j);
        }
        ao=clamp(ao,0.16,1.0);
        float shift=0.5+0.5*sin(info.y*5.0+p.z*0.8);
        float3 tint=mix(float3(0.04,0.46,0.64),float3(0.70,0.08,0.28),shift);
        color=tint*(0.012+d*0.65*shadow)*ao;
        color+=float3(0.025,0.56,0.95)*d2*0.22*ao;
        color+=float3(0.56,0.12,0.74)*fresnel*0.28;
        color+=float3(1.0,0.70,0.37)*spec*1.9*shadow;
        color+=float3(1.0,0.26,0.08)*pow(1.0-ao,3.0)*0.6;
        color*=exp(-0.08*t);
    }
    // Luminous orbital dust, correctly occluded by the fractal surface.
    float3 ringNormal=normalize(float3(0.24,0.85,0.46));
    float denominator=dot(rd,ringNormal);
    float rt=-dot(ro,ringNormal)/denominator;
    if (rt>0 && (!hit || rt<t)) {
        float3 rp=ro+rd*rt;
        float radius=length(rp);
        float angle=atan2(rp.z,rp.x);
        float dust=0.25+0.75*pow(0.5+0.5*sin(angle*130.0+phase*2.0),8.0);
        float band=exp(-pow((radius-1.61)/0.012,2.0))*0.8;
        band+=exp(-pow((radius-1.68)/0.035,2.0))*dust*0.25;
        band+=exp(-pow((radius-1.83)/0.003,2.0))*0.18;
        color+=mix(float3(0.08,0.55,1.0),float3(1.0,0.30,0.20),0.5+0.5*sin(angle))*band;
    }
    color+=float3(0.12,0.16,0.5)*glow*0.5;
    color+=float3(0.006,0.001,0.018)*exp(-dot(uv,uv)*9.0);
    color=1.0-exp(-color*1.8);
    color=pow(clamp(color,0.0,1.0),float3(0.57));
    pixels[gid.y*params.width+gid.x]=uchar4(uchar3(color*255.0),255);
}
