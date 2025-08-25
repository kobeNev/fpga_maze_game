library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity seg_driver_mmss is
    Port (
        clk     : in  STD_LOGIC;
        rst     : in  STD_LOGIC;
        minutes : in  INTEGER;
        seconds : in  INTEGER;
        seg     : out STD_LOGIC_VECTOR(6 downto 0);
        an      : out STD_LOGIC_VECTOR(3 downto 0)
    );
end seg_driver_mmss;

architecture Behavioral of seg_driver_mmss is
    signal refresh_counter : integer := 0;
    signal digit_select     : integer range 0 to 3 := 0;
    signal current_digit    : integer := 0;

    function to_7seg(val : integer) return STD_LOGIC_VECTOR is
        variable seg_out : STD_LOGIC_VECTOR(6 downto 0);
    begin
        case val is
            when 0 => seg_out := "1000000";
            when 1 => seg_out := "1111001";
            when 2 => seg_out := "0100100";
            when 3 => seg_out := "0110000";
            when 4 => seg_out := "0011001";
            when 5 => seg_out := "0010010";
            when 6 => seg_out := "0000010";
            when 7 => seg_out := "1111000";
            when 8 => seg_out := "0000000";
            when 9 => seg_out := "0010000";
            when others => seg_out := "1111111";
        end case;
        return seg_out;
    end function;
begin

    process(clk, rst)
    begin
        if rst = '1' then
            refresh_counter <= 0;
            digit_select <= 0;
        elsif rising_edge(clk) then
            refresh_counter <= refresh_counter + 1;
            if refresh_counter = 10000 then
                refresh_counter <= 0;
                digit_select <= (digit_select + 1) mod 4;
            end if;
        end if;
    end process;

    process(digit_select, minutes, seconds)
    begin
        case digit_select is
            when 0 =>
                current_digit <= seconds mod 10;
                an <= "1110";
            when 1 =>
                current_digit <= seconds / 10;
                an <= "1101";
            when 2 =>
                current_digit <= minutes mod 10;
                an <= "1011";
            when 3 =>
                current_digit <= minutes / 10;
                an <= "0111";
            when others =>
                current_digit <= 0;
                an <= "1111";
        end case;
        seg <= to_7seg(current_digit);
    end process;

end Behavioral;
