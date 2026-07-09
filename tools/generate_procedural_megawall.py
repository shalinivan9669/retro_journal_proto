"""
Generate procedural placeholder mountain megawall textures.
Use this only for blocking/composition. Final art should be rendered from DEM/Blender/Gaea.

Examples:
  python generate_procedural_megawall.py --width 8192 --height 2048 --out ./out
  python generate_procedural_megawall.py --width 16384 --height 4096 --out ./out_16k
"""
from PIL import Image, ImageFilter
import argparse, os, math
import numpy as np

# Minimal faster variant of the generator used for the included placeholder textures.
# It outputs day/night/alpha/depth/snow/cloud/haze files with the same names expected by Godot materials.

def smooth_noise(width, height, scale=64, seed=0):
    rng=np.random.default_rng(seed)
    arr=(rng.random((max(2,height//scale), max(2,width//scale)))*255).astype(np.uint8)
    img=Image.fromarray(arr,'L').resize((width,height), Image.Resampling.BICUBIC).filter(ImageFilter.GaussianBlur(max(0.5, scale/10)))
    return np.array(img).astype(np.float32)/255.0

def ridge_line(w,h, base_y, amp, freq, seed):
    xs=np.arange(w)
    rng=np.random.default_rng(seed)
    y=np.ones(w)*base_y
    for k in range(1,7):
        phase=rng.random()*math.tau
        y += np.sin(xs/w*math.tau*(freq*k*0.37)+phase)*amp/(k**1.15)
    y -= np.exp(-((xs-w*0.62)/(w*0.055))**2)*h*0.24
    y -= np.exp(-((xs-w*0.36)/(w*0.07))**2)*h*0.14
    return np.clip(y, h*0.05, h*0.62)

def layer_mask(w,h,ridge,feather=24):
    yy=np.arange(h)[:,None]
    return np.clip((yy-ridge[None,:])/feather,0,1).astype(np.float32)

def save_rgb(a,p): Image.fromarray(np.clip(a*255,0,255).astype(np.uint8),'RGB').save(p,optimize=True)
def save_gray(a,p): Image.fromarray(np.clip(a*255,0,255).astype(np.uint8),'L').save(p,optimize=True)
def save_rgba(rgb,a,p): Image.fromarray(np.dstack([np.clip(rgb*255,0,255).astype(np.uint8),np.clip(a*255,0,255).astype(np.uint8)]),'RGBA').save(p,optimize=True)

def main():
    ap=argparse.ArgumentParser()
    ap.add_argument('--width',type=int,default=8192)
    ap.add_argument('--height',type=int,default=2048)
    ap.add_argument('--out',default='procedural_megawall_out')
    args=ap.parse_args()
    os.makedirs(args.out,exist_ok=True)
    w,h=args.width,args.height
    Y=np.linspace(0,1,h)[:,None]
    X=np.linspace(0,1,w)[None,:]
    r=ridge_line(w,h,int(h*0.28),h*0.17,1.7,22)
    m=layer_mask(w,h,r,feather=max(12,h//42))
    n=smooth_noise(w,h,max(16,w//100),7)
    striations=((np.sin((X*14+Y*9+n*0.8)*math.tau)+1)/2)*0.12
    day=np.stack([0.22+0.14*n+striations,0.24+0.12*n+striations*0.7,0.27+0.13*n+striations*0.55],axis=2)*m[...,None]
    night=np.stack([0.026+0.04*n,0.039+0.044*n,0.073+0.06*n],axis=2)*m[...,None]
    top=np.zeros((h,w),dtype=np.float32)
    for x in range(w): top[:,x]=np.clip((np.arange(h)-r[x])/(h*0.28),0,1)
    snow=np.clip(1-top*2.2,0,1)*m*(smooth_noise(w,h,max(12,w//220),11)>0.43)
    day=day*(1-snow[...,None]*0.62)+np.array([0.66,0.70,0.72])*snow[...,None]*0.62
    night=night+np.array([0.20,0.31,0.48])*snow[...,None]*0.42
    depth=m*0.72
    save_rgb(day, os.path.join(args.out,'mountain_megawall_day_custom.png'))
    save_rgb(night, os.path.join(args.out,'mountain_megawall_night_custom.png'))
    save_gray(m, os.path.join(args.out,'mountain_megawall_alpha_custom.png'))
    save_gray(depth, os.path.join(args.out,'mountain_megawall_depth_custom.png'))
    save_gray(snow, os.path.join(args.out,'mountain_megawall_snow_mask_custom.png'))
    print('Generated procedural megawall:', args.out)

if __name__ == '__main__':
    main()
