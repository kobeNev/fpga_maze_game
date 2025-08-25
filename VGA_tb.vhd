library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity VGA_tb is
end VGA_tb;

architecture Behavioral of VGA_tb is

    component top_VGA_PS2_demo is
        Port (
            clk_100MHz : in  STD_LOGIC;
            clr        : in  STD_LOGIC;
            ps2d       : in  STD_LOGIC;
            ps2c       : in  STD_LOGIC;
            hsync      : out STD_LOGIC;
            vsync      : out STD_LOGIC;
            vgaBlue    : out STD_LOGIC_VECTOR (3 downto 0);
            vgaGreen   : out STD_LOGIC_VECTOR (3 downto 0);
            vgaRed     : out STD_LOGIC_VECTOR (3 downto 0)
        );
    end component;

    -- DUT signals
    signal clk_100MHz : STD_LOGIC := '0';
    signal clr        : STD_LOGIC := '1';
    signal ps2d       : STD_LOGIC := '1';
    signal ps2c       : STD_LOGIC := '1';
    signal hsync      : STD_LOGIC;
    signal vsync      : STD_LOGIC;
    signal vgaBlue    : STD_LOGIC_VECTOR (3 downto 0);
    signal vgaGreen   : STD_LOGIC_VECTOR (3 downto 0);
    signal vgaRed     : STD_LOGIC_VECTOR (3 downto 0);

    ----------------------------------------------------------------
    -- PS/2 transmit helper
    ----------------------------------------------------------------
    procedure send_ps2_code(
        signal ps2c : out std_logic;
        signal ps2d : out std_logic;
        code        : in  std_logic_vector(7 downto 0)
    ) is
        variable parity : std_logic := '1';
    begin
        -- Start bit
        ps2d <= '0';
        ps2c <= '1';
        wait for 20 us;

        -- 8 data bits (LSB first)
        for i in 0 to 7 loop
            ps2c <= '0'; wait for 20 us;
            ps2d <= code(i);
            parity := parity xor code(i);
            ps2c <= '1'; wait for 20 us;
        end loop;

        -- Parity bit
        ps2c <= '0'; wait for 20 us;
        ps2d <= parity;
        ps2c <= '1'; wait for 20 us;

        -- Stop bit
        ps2c <= '0'; wait for 20 us;
        ps2d <= '1';
        ps2c <= '1'; wait for 20 us;

        -- Herstel lijn
        ps2d <= '1';
        wait for 20 us;
    end procedure;

    -- handige helper voor een key press + release
    procedure press_and_release(
        signal ps2c : out std_logic;
        signal ps2d : out std_logic;
        code        : in  std_logic_vector(7 downto 0)
    ) is
    begin
        send_ps2_code(ps2c, ps2d, code);   -- make code
        send_ps2_code(ps2c, ps2d, X"F0");  -- break prefix
        send_ps2_code(ps2c, ps2d, code);   -- break code
    end procedure;

begin
    ----------------------------------------------------------------
    -- UUT instance
    ----------------------------------------------------------------
    UUT: top_VGA_PS2_demo
        port map (
            clk_100MHz => clk_100MHz,
            clr        => clr,
            ps2d       => ps2d,
            ps2c       => ps2c,
            hsync      => hsync,
            vsync      => vsync,
            vgaBlue    => vgaBlue,
            vgaGreen   => vgaGreen,
            vgaRed     => vgaRed
        );

    ----------------------------------------------------------------
    -- 100 MHz clock
    ----------------------------------------------------------------
    clk_process : process
    begin
        while true loop
            clk_100MHz <= '0';
            wait for 5 ns;
            clk_100MHz <= '1';
            wait for 5 ns;
        end loop;
    end process;

    ----------------------------------------------------------------
    -- Stimuli
    ----------------------------------------------------------------
    stim_process : process
    begin
        -- Reset
        clr <= '1';
        wait for 20 ns;
        clr <= '0';

        wait for 20 us;

        ----------------------------------------------------------------
        -- Test een aantal bewegingen (player 1 met WASD/arrow codes)
        -- Scan codes (set 2):
        -- 1D = W / UP
        -- 1C = A / LEFT
        -- 1B = S / DOWN
        -- 23 = D / RIGHT   (afhankelijk van je PS2-mapper!)
        ----------------------------------------------------------------
        
        -- Onder
        report "Press DOWN";
        press_and_release(ps2c, ps2d, X"1B");
        wait for 10 us;
    
        -- Rechts x3
        report "Press RIGHT 1";
        press_and_release(ps2c, ps2d, X"23");
        wait for 10 us;
    
        report "Press RIGHT 2";
        press_and_release(ps2c, ps2d, X"23");
        wait for 10 us;
    
        report "Press RIGHT 3";
        press_and_release(ps2c, ps2d, X"23");
        wait for 10 us;
    
        -- Onder
        report "Press DOWN again";
        press_and_release(ps2c, ps2d, X"1B");
        wait for 10 us;

        ----------------------------------------------------------------
        -- Eindig simulatie
        ----------------------------------------------------------------
        wait for 10 us;
        report "Simulation finished." severity note;
        wait;
    end process;

end Behavioral;
