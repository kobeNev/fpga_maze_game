# 🎮 FPGA Maze Game – Basys3 (Artix-7)

Dit project implementeert een **2D doolhofspel** op een **Basys3 FPGA board** met **VGA-uitgang** en **PS/2 toetsenbord**.  
De speler bestuurt een avatar door het doolhof met de pijltjestoetsen en moet het eindpunt bereiken.  
De speeltijd wordt bijgehouden en weergegeven op de **7-segment displays**.

---

## 📋 Features
- VGA-output **640×480 @ 60 Hz** (25 MHz pixelclock).  
- Hardgecodeerd doolhof in **Block RAM**.  
- Besturing via **PS/2 keyboard** (← ↑ → ↓).  
- Collision-detectie met muren.  
- Duidelijk **startpunt (groen)** en **eindpunt (rood)**.  
- Resetfunctie via drukknop.  
- **Timer** zichtbaar op 7-segment display.  
- Optioneel: high-score en pauzefunctie.

---

## 🖼️ Systeemoverzicht
![Schema](docs/schema.png)  
*(RTL block design met top-level en submodules)*

---

## 🧩 Modules
- **`vga_RGB`** – Renderer: tekent doolhof en avatar, collision & doel-detectie.  
- **`vga_sync`** – VGA-timinggenerator (hsync, vsync, pixel-coördinaten).  
- **`top_PS2_CR`** – Keyboardcontroller, wrapper rond:  
  - `PS2` → decodeert toetsenbordscancodes.  
  - `PS2_CR` → vertaalt scancodes naar coördinaten (rij/kolom).  
- **`blk_mem_sprites`** – BRAM met doolhofstructuur.  
- **`timer_mmss`** – Timer voor speeltijd (mm:ss).  
- **`seg_driver_mmss`** – 7-segment driver voor weergave tijd.  
- **`clk_25MHz`** – Clock divider van 100 MHz → 25 MHz.

---

## ⚙️ Hardware & Software
- **FPGA**: Xilinx Artix-7 (Basys3 board)  
- **Software**: Vivado 2019.2  
- **Input**: PS/2 toetsenbord  
- **Output**: VGA-monitor + 7-segment displays  

---

## ▶️ Build & Run
1. Clone dit project:  
   ```bash
   git clone https://github.com/<jouw-username>/fpga-maze-game.git
