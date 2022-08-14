library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use IEEE.math_real.all;
use IEEE.FIXED_PKG.ALL;
                                                                                          
library work;                                                                              
use work.network_data_package.all;                                                         


entity gemm_mult is
    generic(
        WIDTH       : integer := 8;
        NEURONS     : integer := 1; --rows
        INPUTS      : integer := 1; --columns
        
        weights     : STD_LOGIC_VECTOR(max_NEURONS*max_INPUTS*max_WIDTH -1 downto 0) := (others => '1');
        bias        : STD_LOGIC_VECTOR(2*max_NEURONS*max_WIDTH -1 downto 0) := (others => '1')        
    );
    port(
        --control
        clk 	: in STD_LOGIC;
        enable	: in STD_LOGIC_VECTOR(7 downto 0);
        reset	: in STD_LOGIC;

        --input
        input  : in STD_LOGIC_VECTOR(INPUTS*WIDTH -1 downto 0); --vectorized

        --output
        output  : out STD_LOGIC_VECTOR(NEURONS*2*WIDTH -1 downto 0); --vectorized
        done	: out STD_LOGIC_VECTOR(7 downto 0)
    );
end gemm_mult;

architecture arch of gemm_mult is
        
    signal output_s      : STD_LOGIC_VECTOR(2*NEURONS*WIDTH -1 downto 0); --vectorized
    signal enable_s      : STD_LOGIC_VECTOR(7 downto 0);
    signal mult_s        : signed(WIDTH-1 downto 0);

    type neuron_array is array (NEURONS -1 downto 0) of signed(2*WIDTH -1 downto 0);
    type full_matrix  is array (INPUTS -1 downto 0) of neuron_array;              

begin
    combinatorial : process(input, clk)

    constant WIDTH_maxvalue         : integer := 2**(WIDTH - 1) - 1;
    constant WIDTH_doublemaxvalue   : integer := 2**(WIDTH) - 1; 

    variable accum_v            : signed(2*(NEURONS*WIDTH) -1 downto 0);
    variable mult_results_v     : neuron_array := (others =>(others => '0'));
    variable mult_v             : signed(2*WIDTH -1 downto 0) := (others => '0');

    variable test_all_mult_results : full_matrix;

    variable bias_result        : signed(2*WIDTH -1 downto 0) := (others => '0');

    begin
        if (mult_results_v(0)(0) = 'X') then
            mult_results_v := (mult_results_v'range => (mult_results_v(mult_results_v'low)'range => '0'));
        end if;

        --matrix multiplication
        for i in 0 to NEURONS-1 loop
            for j in 0 to INPUTS-1 loop
                mult_v :=  signed(weights( ((j+1)*WIDTH -1) + (i*INPUTS*WIDTH) downto (j*WIDTH) + (i*INPUTS*WIDTH) )) * signed(input( (j+1)*WIDTH -1 downto j*WIDTH ));
                mult_results_v(i) := mult_v + mult_results_v(i);
                test_all_mult_results(j)(i) := mult_v;
            end loop;
            --adding bias
            bias_result := mult_results_v(i) + signed(bias(2*WIDTH*(i+1) -1 downto 2*WIDTH*i));
            output_s((i+1)*2*WIDTH -1 downto (i)*2*WIDTH) <= STD_LOGIC_VECTOR(bias_result);
        end loop;
        
        mult_results_v := (others =>(others => '0'));
        enable_s <= enable;
    end process;

    reset_process:
    process(clk)
        begin
            if (rising_edge(clk)) then
                if reset = '1' then
                    done <= (others=>'0');
                else
                    done <= enable_s;
                    output <= output_s;
                end if;
            end if;
        end process;
end arch;
