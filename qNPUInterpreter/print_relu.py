

def print_relu():
    filename = "relu.vhd"
    f = open(filename, "w")
    
    filebuffer = [
    "library IEEE;", 
    "use IEEE.STD_LOGIC_1164.ALL;", 
    "use IEEE.NUMERIC_STD.ALL;", 
    "use IEEE.math_real.all;", 
    "", 
    "entity relu is", 
    "    generic(", 
    "        WIDTH       : integer := 8;", 
    "        NEURONS     : integer := 5;",
    "        threshold   : integer := 0"
    "    );", 
    "    port(", 
    "        --control", 
    "        clk 	: in STD_LOGIC;", 
	"	     enable	: in STD_LOGIC_VECTOR(7 downto 0);", 
	"	     reset	: in STD_LOGIC;", 
    "", 
    "        --input", 
    "        input   : in STD_LOGIC_VECTOR(NEURONS*WIDTH -1 downto 0);", 
    "", 
    "        --output", 
    "        output  : out STD_LOGIC_VECTOR(NEURONS*WIDTH -1 downto 0);", 
	"	     done	 : out STD_LOGIC_VECTOR(7 downto 0)", 
    "    );", 
    "end relu;", 
    "", 
    "architecture arch of relu is", 
    "", 
    "    signal output_s      : STD_LOGIC_VECTOR(NEURONS*WIDTH -1 downto 0);", 
    "    signal enable_s      : STD_LOGIC_VECTOR(7 downto 0);", 
    "", 
    "begin", 
    "    comb : process(input, enable, reset, clk)", 
    "    begin", 
    "        for i in 0 to NEURONS-1 loop", 
    "            if(to_integer(signed(input((i+1)*WIDTH -1 downto i*WIDTH))) < threshold) then", 
    "                output_s((i+1)*WIDTH -1 downto i*WIDTH) <= std_logic_vector(to_signed(threshold, WIDTH));", 
    "            else", 
    "                output_s((i+1)*WIDTH -1 downto i*WIDTH) <= input((i+1)*WIDTH -1 downto i*WIDTH);", 
    "            end if;", 
    "        end loop;", 
    "", 
    "        enable_s <= enable;", 
    "    end process;", 
    "", 
    "    pipeline : process(clk)", 
    "        begin", 
    "            if (rising_edge(clk)) then", 
    "                if reset = '1' then", 
    "                    done <= (others=>'0');", 
    "                else", 
    "                    done <= enable_s;", 
    "                    output <= output_s;", 
    "                end if;", 
    "            end if;", 
    "        end process;", 
    "end arch;"
    ]
    
    f.writelines("%s\n" % line for line in filebuffer)
    f.close()
