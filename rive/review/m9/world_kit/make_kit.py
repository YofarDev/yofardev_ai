"""Scratch evidence for the M9 world kit (moon_rig, hide_when_phased, festive_lights, trail_dots) on a 600x600 artboard.

    uv run rive/review/m9/world_kit/make_kit.py rive/tools <out dir>   # then: rive <out dir> --screenshot=... --data=moonPhase=0.3
"""
import sys, os
sys.path.insert(0, sys.argv[1])
import gen_scenes, world_kit
from rml import write
out = sys.argv[2]
sc = gen_scenes.Scene("beach")
d9 = sc.d9
lit = sc.E((300, 200), "MoonLit", 300, 200, 160, 160, sc.F("FFF4ECD8"))
crater = sc.E((300, 200), "Crater", 330, 180, 30, 24, sc.F("FFD8CCB4"))
lit_node = sc.node("MoonArt", 0, 0, crater, lit)
moon = world_kit.moon_rig(sc, d9, 300, 200, 80, lit_node, "E60E1630")
old = world_kit.hide_when_phased(sc, d9, "M8Moon", [sc.E((0, 0), "OldMoon", 300, 200, 150, 150, sc.F("FFFF0000"))])
lights = world_kit.festive_lights(sc, d9, [(60, 380), (160, 410), (260, 425), (360, 425), (460, 410), (540, 380)],
                                  ("FFFFD27A", "FFFF6B6B"))
trail = world_kit.trail_dots(sc, d9, "FF6E6656", "FFB8AC94", 14)
bg = sc.d("Shape", sc.d("Rectangle", width=600.0, height=600.0, originX=0.0, originY=0.0, name="Path"),
          sc.F("FF0E1630"), x=0.0, y=0.0, name="Bg")
d = sc.d
sm = d("StateMachine", *sc.layers, name="Main")
style = d("LayoutComponentStyle", name="Artboard Style")
ab = d("Artboard", style, sm, sc.ease, sc.ease_out, sc.ease_in, trail, lights, moon, old, bg, *sc.anims,
       width=600.0, height=600.0, name="Scene", defaultStateMachineId=sm.ref(), viewModelId=sc.vm.ref(),
       viewModelInstanceId=sc.inst.ref(), styleId=style.ref(), clip=True)
write(os.path.join(out, "kit.rml"), [ab, sc.enum, sc.npc_enum, sc.vm, *sc.roots])
open(os.path.join(out, "rive.yaml"), "w").write("name: kit\nmain: Scene\noutput: {dir: build}\n")
print("ok")
