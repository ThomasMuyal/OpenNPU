library IEEE;                                                                                                                                                       
use IEEE.STD_LOGIC_1164.ALL;                                                                                                                                        
use IEEE.NUMERIC_STD.ALL;                                                                                                                                           
use IEEE.math_real.all;                                                                                                                                             
use IEEE.FIXED_PKG.ALL;                                                                                                                                             
                                                                                                                                                                    
library work;                                                                                                                                                       
use work.network_data_package.all;                                                                                                                                  
                                                                                                                                                                    
entity gemm_quantize is                                                                                                                                             
    generic(                                                                                                                                                        
        WIDTH       : integer := 8;                                                                                                                                 
        NEURONS     : integer := 1; --rows                                                                                                                          
        INPUTS      : integer := 1; --columns                                                                                                                       
                                                                                                                                                                    
                                                                                                                                                                    
        --quantization parameters                                                                                                                                   
        Z2, Z3      : integer := 0; --weights and output zeropoints                                                                                                 
        --NZ1Z2       : integer := 1; --precalculated parameter                                                                                                     
        M0          : ufixed(-1 downto -4*8) := (others => '0'); --M = (S1*S2)/S3, which are the scales, 8 = WIDTH, generic cannot be used in its own interface list
        n           : integer := 2;                   --M = M0 * 2^(-n)                                                                                             
                                                                                                                                                                    
        a2z1          : a2z1_array := (1, 1, 1)                                                                                                                         
    );                                                                                                                                                              
    port(                                                                                                                                                           
        --control                                                                                                                                                   
        clk 	: in STD_LOGIC;                                                                                                                                      
        enable	: in STD_LOGIC_VECTOR(7 downto 0);                                                                                                                   
        reset	: in STD_LOGIC;                                                                                                                                      
                                                                                                                                                                    
        --input                                                                                                                                                     
        input  : in STD_LOGIC_VECTOR(NEURONS*2*WIDTH -1 downto 0); --vectorized                                                                                     
                                                                                                                                                                    
        --output                                                                                                                                                    
        output  : out STD_LOGIC_VECTOR(NEURONS*WIDTH -1 downto 0); --vectorized                                                                                     
        done	: out STD_LOGIC_VECTOR(7 downto 0)                                                                                                                   
    );                                                                                                                                                              
end gemm_quantize;                                                                                                                                                  
                                                                                                                                                                    
architecture arch of gemm_quantize is                                                                                                                               
--signals                                                                                                                                                           
signal input_s       : STD_LOGIC_VECTOR(NEURONS*2*WIDTH -1 downto 0);                                                                                               
signal output_s      : STD_LOGIC_VECTOR(NEURONS*WIDTH -1 downto 0);                                                                                                 
signal enable_s      : STD_LOGIC_VECTOR(7 downto 0);                                                                                                                
                                                                                                                                                                    
type   t_state       is (state_ready, state_zeropoint, state_M0, state_bitshift, state_overflow, state_end);                                                        
signal state_s       : t_state := state_ready;                                                                                                                      
                                                                                                                                                                    
signal  i            : natural range 0 to NEURONS := 0;                                                                                                             
                                                                                                                                                                    
type   t_zeropoint_array is array(0 to NEURONS - 1) of signed(2*WIDTH -1 downto 0);                                                                                 
signal zeropoint_result   : t_zeropoint_array := (others =>(others => '0'));                                                                                        
                                                                                                                                                                    
type   t_M0_result_array is array(0 to NEURONS - 1) of signed(zeropoint_result(0)'length + 1 downto 0);                                                             
signal M0_result : t_M0_result_array := (others =>(others => '0'));                                                                                                 
                                                                                                                                                                    
type   t_quant_result_array is array(0 to NEURONS - 1) of signed(zeropoint_result(0)'length + 1 downto 0);                                                          
signal quant_result       : t_quant_result_array := (others =>(others => '0'));                                                                                     
                                                                                                                                                                    
                                                                                                                                                                    
begin                                                                                                                                                               
    fsm:                                                                                                                                                            
    process(clk, reset)                                                                                                                                             
    begin                                                                                                                                                           
        if (rising_edge(clk)) then                                                                                                                                  
            if reset = '1' then                                                                                                                                     
                state_s <= state_ready;                                                                                                                             
                output <= (others => '0');                                                                                                                          
                done <= (others => '0');                                                                                                                            
                input_s <= (others => '0');                                                                                                                         
                enable_s <= (others => '0');                                                                                                                        
                i <= 0;                                                                                                                                             
            else                                                                                                                                                    
                case state_s is                                                                                                                                     
                    when state_ready      =>                                                                                                                        
                        if enable /= "00000000" then                                                                                                                
                            state_s <= state_zeropoint;                                                                                                             
                            input_s <= input;                                                                                                                       
                            enable_s <= enable;                                                                                                                     
                            i <= 0;                                                                                                                                 
                        else                                                                                                                                        
                            state_s <= state_ready;                                                                                                                 
                            input_s <= (others => '0');                                                                                                             
                            enable_s <= (others => '0');                                                                                                            
                                                                                                                                                                    
                        end if;                                                                                                                                     
                    when state_zeropoint  =>                                                                                                                        
                        if (i = NEURONS-1) then                                                                                                                     
                            state_s <= state_M0;                                                                                                                    
                            i <= 0;                                                                                                                                 
                        else                                                                                                                                        
                            i <= i + 1;                                                                                                                             
                            state_s <= state_zeropoint;                                                                                                             
                        end if;                                                                                                                                     
                                                                                                                                                                    
                    when state_M0         =>                                                                                                                        
                        if (i = NEURONS-1) then                                                                                                                     
                            state_s <= state_bitshift;                                                                                                              
                            i <= 0;                                                                                                                                 
                        else                                                                                                                                        
                            i <= i + 1;                                                                                                                             
                            state_s <= state_M0;                                                                                                                    
                        end if;                                                                                                                                     
                                                                                                                                                                    
                    when state_bitshift   =>                                                                                                                        
                        if (i = NEURONS-1) then                                                                                                                     
                            state_s <= state_overflow;                                                                                                              
                            i <= 0;                                                                                                                                 
                        else                                                                                                                                        
                            i <= i + 1;                                                                                                                             
                            state_s <= state_bitshift;                                                                                                              
                        end if;                                                                                                                                     
                                                                                                                                                                    
                    when state_overflow   =>                                                                                                                        
                        if (i = NEURONS-1) then                                                                                                                     
                            state_s <= state_end;                                                                                                                   
                            i <= 0;                                                                                                                                 
                        else                                                                                                                                        
                            i <= i + 1;                                                                                                                             
                            state_s <= state_overflow;                                                                                                              
                        end if;                                                                                                                                     
                                                                                                                                                                    
                    when state_end       =>                                                                                                                         
                        output <= output_s;                                                                                                                         
                        done <= enable_s;                                                                                                                           
                        state_s <= state_ready;                                                                                                                     
                end case;                                                                                                                                           
            end if;                                                                                                                                                 
        end if;                                                                                                                                                     
    end process;                                                                                                                                                    
                                                                                                                                                                    
                                                                                                                                                                    
    combinatorial:                                                                                                                                                  
    process(clk)                                                                                                                                                    
                                                                                                                                                                    
    constant WIDTH_maxvalue         : integer := 2**(WIDTH - 1) - 1;                                                                                                
    constant WIDTH_doublemaxvalue   : integer := 2**(WIDTH) - 1;                                                                                                    
                                                                                                                                                                    
    variable bias_result        : signed(2*WIDTH -1 downto 0) := (others => '0');                                                                                   
    --variable zeropoint_result   : signed(2*WIDTH -1 downto 0) := (others => '0');                                                                                 
                                                                                                                                                                    
    variable M0_intermediate_sf : sfixed(zeropoint_result(0)'length + 1 downto M0'low);                                                                             
                                                                                                                                                                    
    --variable M0_result          : signed(M0_intermediate_sf'high downto 0) := (others => '0');                                                                    
    --variable quant_result       : signed(M0_intermediate_sf'high downto 0) := (others => '0');                                                                    
    variable rounding           : signed(2*WIDTH -1 downto 0) := (others => '0');                                                                                   
                                                                                                                                                                    
    --variable i                  : natural range 0 to NEURONS := 0;                                                                                                
    --quantization parameters                                                                                                                                       
    begin                                                                                                                                                           
        if rising_edge(clk) then                                                                                                                                    
        case state_s is                                                                                                                                             
            when state_ready       =>                                                                                                                               
                                                                                                                                                                    
            -- adding quantization factors                                                                                                                          
            -- zeropoint_result := bias_result + a1z2 + z1a2(i) + NZ1Z2, but considering Z1 = 0:                                                                        
            when state_zeropoint   =>                                                                                                                               
                --bias_result := signed(input((i+1)*2*WIDTH -1 downto (i)*2*WIDTH));                                                                                
                zeropoint_result(i) <= signed(input_s((i+1)*2*WIDTH -1 downto (i)*2*WIDTH)) + to_signed(a2z1(i), bias_result'length);                                 
                                                                                                                                                                    
            -- multiplying by M:                                                                                                                                    
            --  first, multiply by M0                                                                                                                               
            when state_M0          =>                                                                                                                               
                M0_intermediate_sf := to_sfixed(to_integer(zeropoint_result(i)), zeropoint_result(i)'length, 0) * to_sfixed(M0);                                    
                M0_result(i) <= signed(STD_LOGIC_VECTOR((M0_intermediate_sf(M0_intermediate_sf'high downto 0))));                                                   
                                                                                                                                                                    
            --  then, multiply by 2^(-n), which is a round-to-nearest right shift by n bits                                                                         
            --  round-to-nearest behaviour achieved by adding 2^(n-1)                                                                                               
            when state_bitshift    =>                                                                                                                               
                rounding := shift_left(signed(to_signed(1, rounding'length)), n-1);                                                                                 
                quant_result(i) <= Z3 + shift_right(M0_result(i) + rounding, n);                                                                                    
                                                                                                                                                                    
            -- overflow treatment                                                                                                                                   
            when state_overflow    =>                                                                                                                               
                                                                                                                                                                    
                if to_integer(quant_result(i)) > WIDTH_maxvalue then                                                                                                
                    output_s((i+1)*WIDTH -1 downto i*WIDTH) <= STD_LOGIC_VECTOR(to_signed(WIDTH_maxvalue, WIDTH));                                                  
                elsif to_integer(quant_result(i)) < (-1)*WIDTH_maxvalue then                                                                                        
                    output_s((i+1)*WIDTH -1 downto i*WIDTH) <= STD_LOGIC_VECTOR(to_signed((-1)*WIDTH_maxvalue -1, WIDTH));                                          
                else                                                                                                                                                
                    output_s((i+1)*WIDTH -1 downto i*WIDTH) <= STD_LOGIC_VECTOR(resize(quant_result(i), WIDTH));                                                    
                end if;                                                                                                                                             
                                                                                                                                                                    
            when state_end        =>                                                                                                                                
        end case;                                                                                                                                                   
        end if;                                                                                                                                                     
    end process;                                                                                                                                                    
end arch;                                                                                                                                                           
