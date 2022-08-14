library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.numeric_std.ALL;
  
entity frequency_divider is
    port(
        clk         : in STD_LOGIC;
        reset       : in STD_LOGIC;
        clock_out   : out STD_LOGIC
        );
end frequency_divider;
  
architecture arch of frequency_divider is
begin
    
    process(clk, reset)
    variable count            : natural range 0 to 4 := 1;
    variable clock_out_v      : STD_LOGIC := '0';
    begin
        if(reset = '1') then
            count   := 0;
            clock_out_v     := '0';
        elsif(clk'event and clk = '1') then
            if (count = 4) then --5
                clock_out_v := NOT clock_out_v;
                count := 0;
            else
                count := count + 1;
            end if;
        end if;
        clock_out <= clock_out_v;
end process;
end arch;
