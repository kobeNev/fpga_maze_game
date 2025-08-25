----------------------------------------------------------------------------------
-- top_VGA_PS2_demo (aangepast)
----------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
-- use IEEE.NUMERIC_STD.ALL; -- niet vereist in dit bestand

entity top_VGA_PS2_demo is
    Port ( clk_100MHz : in  STD_LOGIC;
           clr        : in  STD_LOGIC;
           ps2d       : in  STD_LOGIC;
           ps2c       : in  STD_LOGIC;
           hsync      : out STD_LOGIC;
           vsync      : out STD_LOGIC;
           vgaBlue    : out STD_LOGIC_VECTOR (3 downto 0);
           vgaGreen   : out STD_LOGIC_VECTOR (3 downto 0);
           vgaRed     : out STD_LOGIC_VECTOR (3 downto 0);
           seg : out STD_LOGIC_VECTOR(6 downto 0);
           an  : out STD_LOGIC_VECTOR(3 downto 0));
end top_VGA_PS2_demo;

architecture Behavioral of top_VGA_PS2_demo is
  component clk_25MHz
  port (
    clk_out1 : out std_logic;
    reset    : in  std_logic;
    locked   : out std_logic;
    clk_in1  : in  std_logic
  );
  end component;
  
  component timer_mmss is
    Port (
           clk     : in  STD_LOGIC;
           rst     : in  STD_LOGIC;
           stop    : in  STD_LOGIC;
           minutes  : out INTEGER;
           seconds  : out INTEGER);
  end component;
  
  component seg_driver_mmss is
    Port (
        clk     : in  STD_LOGIC;
        rst     : in  STD_LOGIC;
        minutes : in  INTEGER;
        seconds : in  INTEGER;
        seg     : out STD_LOGIC_VECTOR(6 downto 0);
        an      : out STD_LOGIC_VECTOR(3 downto 0));
  end component;

  component vga_sync is
    Port ( clk   : in  STD_LOGIC;
           clr   : in  STD_LOGIC;
           hsync : out std_logic; 
           vsync : out std_logic; 
           hc    : out std_logic_vector(9 downto 0); 
           vc    : out std_logic_vector(9 downto 0); 
           vidon : out std_logic );
  end component;

  component vga_RGB is
    Port ( clk   : in  STD_LOGIC;  -- NIEUW
           rst   : in  STD_LOGIC;  -- NIEUW
           M     : in  STD_LOGIC_VECTOR (15 downto 0);
           hc    : in  STD_LOGIC_VECTOR (9 downto 0);
           vc    : in  STD_LOGIC_VECTOR (9 downto 0);
           sw    : in  STD_LOGIC_VECTOR (18 downto 0);
           vidon : in  STD_LOGIC;
           blue  : out STD_LOGIC_VECTOR (3 downto 0);
           green : out STD_LOGIC_VECTOR (3 downto 0);
           red   : out STD_LOGIC_VECTOR (3 downto 0);
           rom_addr4 : out STD_LOGIC_VECTOR (4 downto 0);
           at_goal : out STD_LOGIC);
  end component;

  component top_PS2_CR is
    Port ( clk : in  STD_LOGIC;
           clr : in  STD_LOGIC;
           ps2c : in STD_LOGIC;
           ps2d : in STD_LOGIC;
           C1 : out STD_LOGIC_VECTOR (5 downto 0);
           R1 : out STD_LOGIC_VECTOR (4 downto 0));
  end component;

  component blk_mem_sprites
    port (
      clka  : in  STD_LOGIC;
      addra : in  STD_LOGIC_VECTOR(4 downto 0);
      douta : out STD_LOGIC_VECTOR(15 downto 0)
    );
  end component;
  
  --at_goal timer
  signal at_goal        : std_logic;
  signal timer_minutes  : integer := 0;
  signal timer_seconds  : integer := 0;

  -- klokken & sync
  signal clk_25 : std_logic;

  -- sprite ROM interface
  signal addra : std_logic_vector (4 downto 0);
  signal douta : std_logic_vector (15 downto 0);

  -- VGA timing
  signal hc    : std_logic_vector(9 downto 0);
  signal vc    : std_logic_vector(9 downto 0);
  signal vidon : std_logic;

  -- PS2 ? (C1,C2,R1,R2) ? sw-bus (CDC synchronized)
  signal C1_ps2 : std_logic_vector(5 downto 0);
  signal C2_ps2 : std_logic_vector(3 downto 0);
  signal R1_ps2 : std_logic_vector(4 downto 0);
  signal R2_ps2 : std_logic_vector(3 downto 0);

  signal sw_ps2    : std_logic_vector(18 downto 0);
  signal sw_sync1  : std_logic_vector(18 downto 0);
  signal sw_sync2  : std_logic_vector(18 downto 0);

  -- bus naar vga_RGB
  signal sw       : std_logic_vector(18 downto 0);
begin
  ----------------------------------------------------------------
  -- Clockgen 100MHz -> 25MHz
  ----------------------------------------------------------------
  U1 : clk_25MHz
    port map (
      clk_out1 => clk_25,
      reset    => clr,
      locked   => open,
      clk_in1  => clk_100MHz
    );

  ----------------------------------------------------------------
  -- VGA timing @ 25MHz
  ----------------------------------------------------------------
  U2: vga_sync 
    port map(
      clk   => clk_25,
      clr   => clr,
      hsync => hsync, 
      vsync => vsync, 
      hc    => hc, 
      vc    => vc, 
      vidon => vidon
    ); 

  ----------------------------------------------------------------
  -- PS/2 keyboard (laat op 100MHz of zet ook op 25MHz; hier 100MHz)
  ----------------------------------------------------------------
  U5: top_PS2_CR
    port map (
      clk  => clk_100MHz,
      clr  => clr,
      ps2c => ps2c,
      ps2d => ps2d,
      C1   => C1_ps2,
      R1   => R1_ps2
    );

  -- bundel naar één bus (PS2-domein)
  sw_ps2(5 downto 0)    <= C1_ps2;         -- kolom (tile)
  sw_ps2(10 downto 6)   <= R1_ps2;         -- rij (tile)

  -- CDC: twee-flop synchronizer naar 25MHz domein
  process(clk_25, clr)
  begin
    if clr = '1' then
      sw_sync1 <= (others => '0');
      sw_sync2 <= (others => '0');
    elsif rising_edge(clk_25) then
      sw_sync1 <= sw_ps2;
      sw_sync2 <= sw_sync1;
    end if;
  end process;

  sw <= sw_sync2;

  ----------------------------------------------------------------
  -- Sprite ROM (clock op 25MHz zodat addra/douta in hetzelfde domein zitten)
  ----------------------------------------------------------------
  U4 : blk_mem_sprites
    port map (
      clka  => clk_25,   -- AANPASSING: was clk_100MHz
      addra => addra,
      douta => douta
    );

  ----------------------------------------------------------------
  -- VGA renderer + collision @ 25MHz
  ----------------------------------------------------------------
  U3: vga_RGB 
    port map (
      clk       => clk_25,   -- NIEUW
      rst       => clr,      -- NIEUW
      M         => douta,
      hc        => hc,
      vc        => vc,
      sw        => sw,
      vidon     => vidon,
      blue      => vgaBlue,
      green     => vgaGreen,
      red       => vgaRed,
      rom_addr4 => addra,
      at_goal => at_goal
    );
    
  ----------------------------------------------------------------
  -- Timer voor bijhouden speeltijd doolhof
  ----------------------------------------------------------------
  U6: timer_mmss
    port map (
        clk  => clk_25,
        rst  => clr,
        stop => at_goal,
        minutes => timer_minutes,
        seconds => timer_seconds
    );
    
  ----------------------------------------------------------------
  -- 7-segment driver
  ----------------------------------------------------------------
  U7: seg_driver_mmss
    port map (
        clk     => clk_100MHz,
        rst     => clr,
        minutes => timer_minutes,
        seconds => timer_seconds,
        seg     => seg,
        an      => an
    );
end Behavioral;
