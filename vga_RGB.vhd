library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity vga_RGB is
    Port (
        clk   : in  STD_LOGIC;  -- toegevoegde klok voor state (collision/positie)
        rst   : in  STD_LOGIC;  -- asynchrone reset, '1' = reset spelerpositie
        M     : in  STD_LOGIC_VECTOR (15 downto 0);      -- sprite lijnbits (16 px)
        hc    : in  STD_LOGIC_VECTOR (9 downto 0);       -- horizontale pixelcounter
        vc    : in  STD_LOGIC_VECTOR (9 downto 0);       -- verticale pixelcounter
        sw    : in  STD_LOGIC_VECTOR (18 downto 0);      -- gebruikt als position request
        vidon : in  STD_LOGIC;                           -- actief video-gebied
        blue  : out STD_LOGIC_VECTOR (3 downto 0);
        green : out STD_LOGIC_VECTOR (3 downto 0);
        red   : out STD_LOGIC_VECTOR (3 downto 0);
        rom_addr4 : out STD_LOGIC_VECTOR (4 downto 0);    -- sprite ROM adres (laagste 5 bits)
        at_goal : out STD_LOGIC
    );
end vga_RGB;

architecture Behavioral of vga_RGB is
    -- Timings: back porch (10-bit vectors)
    constant hbp : STD_LOGIC_VECTOR(9 downto 0) := "0010010000"; -- 144
    constant vbp : STD_LOGIC_VECTOR(9 downto 0) := "0000011111"; -- 31

    -- Sprite-afmetingen
    constant w : integer := 16; -- breedte  (px)
    constant h : integer := 16; -- hoogte   (px)

    -- Maze ROM: 32 rijen (0..31) x 49 kolommen (0..48)
    type maze_rom_type is array (0 to 31) of STD_LOGIC_VECTOR(48 downto 0);
    constant maze_rom : maze_rom_type := (
        "1111111111111111111111111111111111111111111111101",
        "1111111111100000000001010000000000010000000000001",
        "1111111111101111111101011111111011110111111111111",
        "1111111111100100000101000000001010000100000000001",
        "1111111111100001110101111111101010111111111011101",
        "1111111111100101000100000000100010000000001010101",
        "1111111111111101011111111101111111011111101010111",
        "1111111111100101000000000000000000010000001000001",
        "1111111111110101111111111111111111010111111111111",
        "1111111111110001000000000000000000010000000000001",
        "1111111111111111011111111111111101110111111111111",
        "1111111111100000010000000000000001000000000000001",
        "1111111111111111010111111111111101111111111111111",
        "1111111111100001010100000000000101000000000000001",
        "1111111111101101010111111111101101011111111111101",
        "1111111111101100010000000000100001010000000000101",
        "1111111111101111111111111101111111010111111111101",
        "1111111111100000000000000100000000010000000010001",
        "1111111111100111111111101111111111110111111010111",
        "1111111111100000000000100000000000000100000010001",
        "1111111111111111111101111111111111111101111111101",
        "1111111111100000000100000000000000000001000000001",
        "1111111111101101110101111111111111111111111111101",
        "1111111111100101010111111110001100011111111111101",
        "1111111111110100010000000000100001010000000000101",
        "1111111111110111111111111101111111010111111111101",
        "1111111111110000000000000100000000010000000010001",
        "1111111111100111111111101111111011110111111010101",
        "1111111111101111111111101000001000000111000000101",
        "1111111111101111111111111111111111111111111111111",
        "1111111111111111111111111111111111111111111111111",
        "1111111111111111111111111111111111111111111111111"
    );

    -- Interne posities (tiles) mét collision
    signal player_row : integer range 0 to 31 := 0;
    signal player_col : integer range 0 to 48 := 1;
    
    -- Signalen voor herkenning start en finish
    signal at_start : std_logic;

    -- Aangevraagde positie (van SW) als tiles
    signal req_row    : integer range 0 to 31;
    signal req_col    : integer range 0 to 48;

    -- Sprite draw-positie in pixels (actieve-gebied coördinaten)
    signal C1_draw, R1_draw : STD_LOGIC_VECTOR(9 downto 0);

    -- Sprite enable
    signal spriteon1: STD_LOGIC;

    -- Sprite ROM adressering
    signal rom_addr, rom_pix : STD_LOGIC_VECTOR(9 downto 0);

    -- Maze tekenen
    signal maze_row : STD_LOGIC_VECTOR(4 downto 0); -- 0..31
    signal maze_col : STD_LOGIC_VECTOR(5 downto 0); -- 0..63 (we clippen naar 0..48)
    signal maze_bit : STD_LOGIC;
    
    -- eenvoudige clamp helper (VHDL-93/2002 compatibel)
    function clamp(val : integer; lo : integer; hi : integer) return integer is
      variable r : integer := val;
    begin
      if r < lo then
        r := lo;
      elsif r > hi then
        r := hi;
      end if;
      return r;
    end function;


begin
    
    -- 1) Aanvraag van positie uit switches (tiles)
    req_row <= clamp(to_integer(unsigned(sw(10 downto 6))), 0, 31);
    req_col <= clamp(to_integer(unsigned(sw(5 downto 0))), 0, 48);

    
    -- 2) Collision gating op klok: alleen updaten als doel geen muur is
    process(clk, rst)
        variable dr, dc : integer;             -- -1, 0, +1
        variable cand_r : integer;
        variable cand_c : integer;
    begin
        if rst = '1' then
            player_row <= 0;
            player_col <= 1;
            
        elsif rising_edge(clk) then
            -- Bepaal gewenste richting tov huidige positie (maximaal 1 stap)
            dr := 0; dc := 0;
            if req_row > player_row then
                dr := 1;
            elsif req_row < player_row then
                dr := -1;
            end if;
    
            if req_col > player_col then
                dc := 1;
            elsif req_col < player_col then
                dc := -1;
            end if;
    
            -- Kies 1 as per klok (axis-lock): eerst horizontaal, dan verticaal
            -- (wil je liever verticaal eerst, verwissel de blokken)
            cand_r := player_row;
            cand_c := player_col;
    
            if dc /= 0 then
                cand_c := clamp(player_col + dc, 0, 48);
                -- check tussenliggende tegel
                if maze_rom(cand_r)(cand_c) = '0' then
                    player_col <= cand_c;      -- stap 1 kolom
                end if;
    
            elsif dr /= 0 then
                cand_r := clamp(player_row + dr, 0, 31);
                if maze_rom(cand_r)(cand_c) = '0' then
                    player_row <= cand_r;      -- stap 1 rij
                end if;
            end if;
        end if;
    end process;
    
    at_start <= '1' when (player_row = 1 and player_col = 1) else '0';
    at_goal  <= '1' when (player_row = 29 and player_col = 37) else '0';

    -- 3) Pixelpositie van sprite (actieve gebied): tile * 16 (+ kleine Y offset)
    C1_draw <= std_logic_vector( to_unsigned(player_col, 10) sll 4 );                 -- *16
    R1_draw <= std_logic_vector( (to_unsigned(player_row, 10) sll 4) + to_unsigned(0,10) );

    -- 4) Sprite-vensters (numeric_std)
    spriteon1 <= '1' when
        ( unsigned(hc) >= unsigned(C1_draw) + unsigned(hbp) and
          unsigned(hc) <  unsigned(C1_draw) + unsigned(hbp) + to_unsigned(w, 10) and
          unsigned(vc) >= unsigned(R1_draw) + unsigned(vbp) and
          unsigned(vc) <  unsigned(R1_draw) + unsigned(vbp) + to_unsigned(h, 10) )
    else '0';

    -- 5) Tekenlogica: sprites > anders maze-achtergrond
    process(hc, vc, vidon, spriteon1, M, R1_draw, C1_draw)
        variable j     : integer;
        variable act_h : unsigned(9 downto 0);
        variable act_v : unsigned(9 downto 0);
        variable tile_x, tile_y : integer;
        variable bit_maze : std_logic;
    begin
        -- default zwart
        red   <= (others => '0');
        green <= (others => '0');
        blue  <= (others => '0');
        rom_addr4 <= (others => '0');

        if vidon = '1' then
            if spriteon1 = '1' then
                -- sprite 1: bereken adres en pixel binnen sprite
                rom_addr <= std_logic_vector( unsigned(vc) - unsigned(vbp) - unsigned(R1_draw) );
                rom_pix  <= std_logic_vector( unsigned(hc) - unsigned(hbp) - unsigned(C1_draw) );
                rom_addr4 <= rom_addr(4 downto 0);

                -- index 0..15
                j := to_integer(unsigned(rom_pix(3 downto 0)));
                if M(j) = '1' then
                    -- zwarte sprite op witte achtergrond (zoals bij jou)
                    red   <= "0000";
                    green <= "0000";
                    blue  <= "0000";
                else
                    red   <= "1111";
                    green <= "1111";
                    blue  <= "1111";
                end if;

            else
                -- Maze achtergrond tekenen
                act_h := unsigned(hc) - unsigned(hbp); -- 0..639
                act_v := unsigned(vc) - unsigned(vbp); -- 0..479

                -- /16 == >>4
                tile_x := to_integer(act_h(9 downto 4)); -- 0..39 zichtbaar
                tile_y := to_integer(act_v(8 downto 4)); -- 0..29 zichtbaar

                -- clip naar ROM-bereik (49x32)
                if tile_x < 0 then tile_x := 0; end if;
                if tile_x > 48 then tile_x := 48; end if;
                if tile_y < 0 then tile_y := 0; end if;
                if tile_y > 31 then tile_y := 31; end if;

                bit_maze := maze_rom(tile_y)(tile_x);
                -- In het maze-rendering deel van je process:
                if tile_x = 1 and tile_y = 0 then
                    -- Beginpositie: kleur groen
                    red   <= "0000";
                    green <= "1111";
                    blue  <= "0000";
                
                elsif tile_x = 37 and tile_y = 29 then
                    -- Eindpositie: kleur rood
                    red   <= "1111";
                    green <= "0000";
                    blue  <= "0000";
                
                elsif bit_maze = '1' then
                    -- muur: zwart
                    red   <= "0000";
                    green <= "0000";
                    blue  <= "0000";
                else
                    -- pad: wit
                    red   <= "1111";
                    green <= "1111";
                    blue  <= "1111";
                end if;
            end if;
        end if;
    end process;

end Behavioral;
