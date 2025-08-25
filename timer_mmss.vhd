library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity timer_mmss is
    Port (
        clk     : in  STD_LOGIC;  -- systeemklok (bv. 50 MHz)
        rst     : in  STD_LOGIC;  -- reset
        stop    : in  STD_LOGIC;  -- stopt timer bij '1' (bv. at_goal)
        minutes  : out INTEGER range 0 to 59;
        seconds  : out INTEGER range 0 to 59
    );
end timer_mmss;

architecture Behavioral of timer_mmss is
    signal cnt : integer := 0;
    signal sec : integer := 0;
    signal min : integer := 0;
begin
    process(clk, rst)
    begin
        if rst = '1' then
            cnt <= 0;
            sec <= 0;
            min <= 0;
        elsif rising_edge(clk) then
            if stop = '0' then
                cnt <= cnt + 1;
                if cnt = 25_000_000 then -- 1 seconde bij 25 MHz
                    cnt <= 0;
                    sec <= sec + 1;
                    if sec = 60 then
                        sec <= 0;
                        min <= min + 1;
                        if min = 60 then
                            min <= 0;
                        end if;
                    end if;
                end if;
            end if;
        end if;
    end process;

    minutes <= min;
    seconds <= sec;
end Behavioral;
