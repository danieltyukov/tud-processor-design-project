#!/usr/bin/env python3
"""Optimization-overview graphic for the PDP deck (slide after side-channel
vulnerabilities). One visual: the three optimizations we built + cumulative
cycle payoff. Palette/fonts match PDP_group24.pptx (TU Delft theme, Arial)."""
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
from matplotlib.patches import FancyBboxPatch, FancyArrowPatch
from matplotlib import font_manager

NAVY="#0C2340"; CYAN="#00A6D6"; PINK="#EF60A3"; ORANGE="#EC6842"
YELLOW="#FFB81C"; GREEN="#6CC24A"; INK="#1b2733"; GREY="#5b6b7a"
# pale fills + darker text variants, to match the deck's pastel flow boxes (slides 10/12)
PALE={NAVY:"#E9EEF4",CYAN:"#E4F5FB",ORANGE:"#FCEDE7",GREEN:"#EDF7E6"}
DARK={NAVY:NAVY,CYAN:"#0089B4",ORANGE:"#C9501E",GREEN:"#4E9B30"}

for fam in ("Arial","Liberation Sans","DejaVu Sans"):
    if any(fam.lower() in f.name.lower() for f in font_manager.fontManager.ttflist):
        plt.rcParams["font.family"]=fam; break

W,H = 1240,560
fig = plt.figure(figsize=(W/100,H/100),dpi=200)
ax = fig.add_axes([0,0,1,1]); ax.set_xlim(0,W); ax.set_ylim(0,H); ax.axis("off")

def box(x,y,w,h,fc,ec,lw=2.2,rad=12,z=1):
    ax.add_patch(FancyBboxPatch((x,y),w,h,fc=fc,ec=ec,lw=lw,zorder=z,
                 boxstyle=f"round,pad=0,rounding_size={rad}"))
def chip(x,y,w,h,label,fc,tc="white",fs=12,ec="none",rad=9,z=4):
    ax.add_patch(FancyBboxPatch((x,y),w,h,fc=fc,ec=ec,lw=1.4,zorder=z,
                 boxstyle=f"round,pad=0,rounding_size={rad}"))
    if label: ax.text(x+w/2,y+h/2,label,ha="center",va="center",color=tc,
                      fontsize=fs,fontweight="bold",zorder=z+1)
def arrow(x0,y0,x1,y1,color=GREY,lw=2.6,mut=16):
    ax.add_patch(FancyArrowPatch((x0,y0),(x1,y1),arrowstyle="-|>",mutation_scale=mut,
                 lw=lw,color=color,zorder=3,shrinkA=0,shrinkB=0))

# ===================== HEADER BAND =====================
box(20,502,1200,46,NAVY,NAVY,lw=0,rad=12,z=2)
ax.text(40,525,"From baseline to optimized AES",ha="left",va="center",
        color="white",fontsize=15,fontweight="bold",zorder=5)
for cx,w,txt,col in ((690,176,"61,184 → 4,104 cyc",CYAN),
                     (878,118,"≈ 15× faster",GREEN),
                     (1006,196,"side-channel hardened",PINK)):
    chip(cx,510,w,30,txt,"#16314d",tc=col,fs=11.5,ec=col,rad=8,z=4)

# ===================== SPINE: cycle-count journey =====================
nodes = [("61,184",NAVY,"baseline"),
         ("6,260", CYAN,"+ HW Zkne"),
         ("4,800", ORANGE,"+ unroll"),
         ("4,104", GREEN,"+ DOM")]
nx=[36,362,688,1014]; NW,NH=200,72; ny=414
for (num,acc,tag),x in zip(nodes,nx):
    box(x,ny,NW,NH,PALE[acc],acc,lw=2.4,rad=12,z=4)
    ax.text(x+NW/2,ny+44,num,ha="center",va="center",color=DARK[acc],fontsize=21,
            fontweight="bold",zorder=6)
    ax.text(x+NW/2,ny+20,"cycles",ha="center",va="center",color=GREY,fontsize=10,zorder=6)
    ax.text(x+NW/2,ny-14,tag,ha="center",va="center",color=DARK[acc],fontsize=10.5,
            fontweight="bold")
# arrows + speedup badges
mids=[]
for i in range(3):
    x0=nx[i]+NW; x1=nx[i+1]; arrow(x0+6,ny+NH/2,x1-6,ny+NH/2,color=NAVY,lw=2.6,mut=15)
    mids.append((x0+x1)/2)
for mx,txt,col in ((mids[0],"9.8×",CYAN),(mids[1],"−23%",ORANGE),(mids[2],"−34%",GREEN)):
    chip(mx-38,ny+NH/2-13,76,26,txt,col,tc="white",fs=12,rad=8,z=5)

# ===================== THREE OPTIMIZATION CARDS =====================
cards=[
 (CYAN,"#EAF7Fc","1","Hardware AES instructions (Zkne)",
  ["aes32esmi / aes32esi fuse SubBytes + ShiftRows +",
   "MixColumns + AddRoundKey into one instruction.",
   "Runs on registers — no BRAM S-box / MixColumns loads.",
   "Removes the MixColumns bottleneck (83.8% of baseline)."],
  "61,184 → 6,260 cyc  ·  9.8× faster"),
 (ORANGE,"#FDEFE9","2","Custom LLVM loop-unroll pass",
  ["Fully unrolls the 9-round AES loop, removing per-round",
   "counter, branch and key-pointer overhead.",
   "Forces the unroll the -Os cost model refuses to do.",
   "Same ciphertext; loop always guaranteed fully unrolled."],
  "6,260 → 4,800 cyc  ·  −23%"),
 (GREEN,"#EEF8E7","3","Parallel DOM S-box (RTL)",
  ["Two DOM-masked S-boxes per instruction — fewer",
   "S-box ops per round, plus first-order SCA resistance.",
   "New EX unit (2 S-boxes) + decoder & pipeline changes.",
   "CPA 0.24 → 0.07,  TVLA |t| 49 → 4.0 (below threshold)."],
  "6,260 → 4,104 cyc  ·  −34%  ·  secure"),
]
cx=[30,428,826]; CW,CH=384,344; cy=36
for (accent,bg,nlabel,title,lines,result),x in zip(cards,cx):
    box(x,cy,CW,CH,"white",accent,lw=2.4,rad=14)
    # pale header strip (matches slides 10/12 pastel style) + thin accent rule
    box(x,cy+CH-52,CW,52,bg,bg,lw=0,rad=14,z=3)
    ax.add_patch(plt.Rectangle((x,cy+CH-52),CW,20,fc=bg,ec="none",zorder=3))
    ax.add_patch(plt.Rectangle((x+2,cy+CH-54),CW-4,2.4,fc=accent,ec="none",zorder=4))
    chip(x+16,cy+CH-44,34,34,nlabel,accent,tc="white",fs=16,rad=8,z=5)
    ax.text(x+62,cy+CH-26,title,ha="left",va="center",color=DARK[accent],
            fontsize=13.5,fontweight="bold",zorder=5)
    # body text, vertically centered between header strip and result chip
    sp=29; top=cy+CH-52; bot=cy+18+40
    ty=(top+bot)/2 + (len(lines)-1)/2*sp
    for ln in lines:
        ax.text(x+20,ty,ln,ha="left",va="center",color=INK,fontsize=10.6)
        ty-=sp
    # result chip pinned near bottom
    chip(x+18,cy+18,CW-36,40,result,bg,tc=DARK[accent],fs=11.5,ec=accent,rad=9,z=4)

out="slides_assets/fig_optim_overview.png"
fig.savefig(out,dpi=200,facecolor="white")
print("wrote",out)
