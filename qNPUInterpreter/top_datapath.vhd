library IEEE;																				                                                                             
use IEEE.STD_LOGIC_1164.ALL;                                                                                                                                            
use IEEE.NUMERIC_STD.ALL;                                                                                                                                               
use IEEE.FIXED_PKG.ALL;                                                                                                                                                 
                                                                                                                                                                        
                                                                                                                                                                        
library work;                                                                                                                                                           
use work.network_data_package.all;                                                                                                                                      
                                                                                                                                                                        
entity top_datapath is                                                                                                                                                  
    port(                                                                                                                                                               
    --control                                                                                                                                                           
    clk 	: in STD_LOGIC;                                                                                                                                              
    enable	: in STD_LOGIC_VECTOR(7 downto 0);                                                                                                                           
    reset	: in STD_LOGIC;                                                                                                                                              
                                                                                                                                                                        
    --input                                                                                                                                                             
    input  : in STD_LOGIC_VECTOR(INPUTS(0)*WIDTH(0) -1 downto 0); --vectorized                                                                                          
                                                                                                                                                                        
    --output                                                                                                                                                            
    output  : out STD_LOGIC_VECTOR(NEURONS(LAYERS-1)*WIDTH(LAYERS-1) -1 downto 0); --vectorized                                                                         
                                                                                                                                                                        
    done	: out STD_LOGIC_VECTOR(7 downto 0)                                                                                                                           
    );                                                                                                                                                                  
end top_datapath;                                                                                                                                                       
                                                                                                                                                                        
architecture arch of top_datapath is                                                                                                                                    
                                                                                                                                                                        
    component frequency_divider is                                                                                                                                      
        port(                                                                                                                                                           
            clk         : in STD_LOGIC;                                                                                                                                 
            reset       : in STD_LOGIC;                                                                                                                                 
            clock_out   : out STD_LOGIC                                                                                                                                 
            );                                                                                                                                                          
    end component;                                                                                                                                                      
                                                                                                                                                                        
    component gemm_mult is                                                                                                                                              
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
    end component;                                                                                                                                                      
                                                                                                                                                                        
    component gemm_quantize is                                                                                                                                          
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
    end component;                                                                                                                                                      
                                                                                                                                                                        
    component relu is                                                                                                                                                   
        generic(                                                                                                                                                        
            WIDTH       : integer := 8;                                                                                                                                 
            NEURONS     : integer := 5;                                                                                                                                 
            threshold     : integer := 0                                                                                                                                
        );                                                                                                                                                              
        port(                                                                                                                                                           
            --control                                                                                                                                                   
            clk 	: in STD_LOGIC;                                                                                                                                      
            enable	: in STD_LOGIC_VECTOR(7 downto 0);                                                                                                                   
            reset	: in STD_LOGIC;                                                                                                                                      
                                                                                                                                                                        
            --input                                                                                                                                                     
            input   : in STD_LOGIC_VECTOR(NEURONS*WIDTH -1 downto 0);                                                                                                   
                                                                                                                                                                        
            --output                                                                                                                                                    
            output  : out STD_LOGIC_VECTOR(NEURONS*WIDTH -1 downto 0);                                                                                                  
            done	: out STD_LOGIC_VECTOR(7 downto 0)                                                                                                                   
        );                                                                                                                                                              
    end component;                                                                                                                                                      
                                                                                                                                                                        
    --signals                                                                                                                                                           
    signal clock_out_s          : STD_LOGIC;                                                                                                                            
    signal output_gemm_mult     : array_double_output_t;                                                                                                                
    signal done_gemm_mult       : array_done_t;                                                                                                                         
    signal output_gemm_quant    : array_output_t;                                                                                                                       
    signal done_gemm_quant      : array_done_t;                                                                                                                         
    signal output_relu          : array_output_t;                                                                                                                       
    signal done_relu            : array_done_t;                                                                                                                         
                                                                                                                                                                        
begin                                                                                                                                                                   
    fdiv: frequency_divider port map(                                                                                                                                   
        clk         => clk,                                                                                                                                             
        reset       => reset,                                                                                                                                           
        clock_out   => clock_out_s                                                                                                                                      
    );                                                                                                                                                                  
                                                                                                                                                                        
    GEN_0: for i in 0 to LAYERS - 1 generate                                                                                                                            
        FIRST_LAYER: if i = 0 generate                                                                                                                                  
            gemm_mult0: gemm_mult generic map(                                                                                                                          
                WIDTH   => WIDTH(0),                                                                                                                                    
                NEURONS => NEURONS(0),                                                                                                                                  
                INPUTS  => INPUTS(0),                                                                                                                                   
                                                                                                                                                                        
                weights => weights(0),                                                                                                                                  
                bias    => bias(0)                                                                                                                                      
            )                                                                                                                                                           
            port map(                                                                                                                                                   
                clk     => clk, --clock_out_s,                                                                                                                          
                enable  => enable,                                                                                                                                      
                reset   => reset,                                                                                                                                       
                                                                                                                                                                        
                input   => input,                                                                                                                                       
                                                                                                                                                                        
                output  => output_gemm_mult(i)(2*WIDTH(0)*NEURONS(0) -1 downto 0),                                                                                      
                done    => done_gemm_mult(i)                                                                                                                            
            );                                                                                                                                                          
                                                                                                                                                                        
            gemm_quantize0: gemm_quantize generic map(                                                                                                                  
                WIDTH   => WIDTH(0),                                                                                                                                    
                NEURONS => NEURONS(0),                                                                                                                                  
                INPUTS  => INPUTS(0),                                                                                                                                   
                                                                                                                                                                        
                Z2      => input_zeropoint(0),                                                                                                                          
                Z3      => output_zeropoint(0),                                                                                                                         
                M0      => M0(0),                                                                                                                                       
                n       => n(0),                                                                                                                                        
                a2z1      => a2z1(0)                                                                                                                                        
            )                                                                                                                                                           
            port map(                                                                                                                                                   
                clk     => clk, --clock_out_s,                                                                                                                          
                enable  => done_gemm_mult(i),                                                                                                                           
                reset   => reset,                                                                                                                                       
                                                                                                                                                                        
                input   => output_gemm_mult(i)(2*WIDTH(0)*NEURONS(0) -1 downto 0),                                                                                      
                                                                                                                                                                        
                output  => output_gemm_quant(i)(WIDTH(0)*NEURONS(0) -1 downto 0),                                                                                       
                done    => done_gemm_quant(i)                                                                                                                           
            );                                                                                                                                                          
                                                                                                                                                                        
            relu0: relu generic map(                                                                                                                                    
                WIDTH   => WIDTH(0),                                                                                                                                    
                NEURONS => NEURONS(0),                                                                                                                                  
                threshold => relu_threshold(0)                                                                                                                          
            )                                                                                                                                                           
            port map(                                                                                                                                                   
                clk     => clk, --clock_out_s,                                                                                                                          
                enable  => done_gemm_quant(i),                                                                                                                          
                reset   => reset,                                                                                                                                       
                                                                                                                                                                        
                input   => output_gemm_quant(i)(WIDTH(0)*NEURONS(0) -1 downto 0),                                                                                       
                                                                                                                                                                        
                output  => output_relu(i)(WIDTH(0)*NEURONS(0) -1 downto 0),                                                                                             
                done    => done_relu(i)                                                                                                                                 
             );                                                                                                                                                         
        end generate FIRST_LAYER;                                                                                                                                       
                                                                                                                                                                        
        HIDDEN_LAYERS: if (i /= 0) and (i /= LAYERS -1) generate                                                                                                        
            gemm_multx: gemm_mult generic map(                                                                                                                          
                WIDTH   => WIDTH(i),                                                                                                                                    
                NEURONS => NEURONS(i),                                                                                                                                  
                INPUTS  => INPUTS(i),                                                                                                                                   
                                                                                                                                                                        
                weights => weights(i),                                                                                                                                  
                bias    => bias(i)                                                                                                                                      
             )                                                                                                                                                          
            port map(                                                                                                                                                   
                clk     => clk, --clock_out_s,                                                                                                                          
                enable  => done_relu(i-1),                                                                                                                              
                reset   => reset,                                                                                                                                       
                                                                                                                                                                        
                input   => output_relu(i-1)(WIDTH(i-1)*NEURONS(i-1) -1 downto 0),                                                                                       
                                                                                                                                                                        
                output  => output_gemm_mult(i)(2*WIDTH(i)*NEURONS(i) -1 downto 0),                                                                                      
                done    => done_gemm_mult(i)                                                                                                                            
            );                                                                                                                                                          
                                                                                                                                                                        
            gemm_quantizex: gemm_quantize generic map(                                                                                                                  
                WIDTH   => WIDTH(i),                                                                                                                                    
                NEURONS => NEURONS(i),                                                                                                                                  
                INPUTS  => INPUTS(i),                                                                                                                                   
                                                                                                                                                                        
                Z2      => input_zeropoint(i),                                                                                                                          
                Z3      => output_zeropoint(i),                                                                                                                         
                M0      => M0(i),                                                                                                                                       
                n       => n(i),                                                                                                                                        
                a2z1      => a2z1(i)                                                                                                                                        
            )                                                                                                                                                           
            port map(                                                                                                                                                   
                clk     => clk, --clock_out_s,                                                                                                                          
                enable  => done_gemm_mult(i),                                                                                                                           
                reset   => reset,                                                                                                                                       
                                                                                                                                                                        
                input   => output_gemm_mult(i)(2*WIDTH(i)*NEURONS(i) -1 downto 0),                                                                                      
                                                                                                                                                                        
                output  => output_gemm_quant(i)(WIDTH(i)*NEURONS(i) -1 downto 0),                                                                                       
                done    => done_gemm_quant(i)                                                                                                                           
            );                                                                                                                                                          
                                                                                                                                                                        
            relux: relu generic map(                                                                                                                                    
                WIDTH   => WIDTH(i),                                                                                                                                    
                NEURONS => NEURONS(i),                                                                                                                                  
                threshold => relu_threshold(i)                                                                                                                          
            )                                                                                                                                                           
            port map(                                                                                                                                                   
                clk     => clk, --clock_out_s,                                                                                                                          
                enable  => done_gemm_quant(i),                                                                                                                          
                reset   => reset,                                                                                                                                       
                                                                                                                                                                        
                input   => output_gemm_quant(i)(WIDTH(i)*NEURONS(i) -1 downto 0),                                                                                       
                                                                                                                                                                        
                output  => output_relu(i)(WIDTH(i)*NEURONS(i) -1 downto 0),                                                                                             
                done    => done_relu(i)                                                                                                                                 
             );                                                                                                                                                         
        end generate HIDDEN_LAYERS;                                                                                                                                     
                                                                                                                                                                        
        LAST_LAYER: if i = LAYERS - 1 generate                                                                                                                          
            gemm_multx: gemm_mult generic map(                                                                                                                          
                WIDTH   => WIDTH(i),                                                                                                                                    
                NEURONS => NEURONS(i),                                                                                                                                  
                INPUTS  => INPUTS(i),                                                                                                                                   
                                                                                                                                                                        
                weights => weights(i),                                                                                                                                  
                bias    => bias(i)                                                                                                                                      
            )                                                                                                                                                           
            port map(                                                                                                                                                   
                clk     => clk, --clock_out_s,                                                                                                                          
                enable  => done_relu(i-1),                                                                                                                              
                reset   => reset,                                                                                                                                       
                                                                                                                                                                        
                input   => output_relu(i-1)(WIDTH(i-1)*NEURONS(i-1) -1 downto 0),                                                                                       
                                                                                                                                                                        
                output  => output_gemm_mult(i)(2*WIDTH(i)*NEURONS(i) -1 downto 0),                                                                                      
                done    => done_gemm_mult(i)                                                                                                                            
            );                                                                                                                                                          
                                                                                                                                                                        
            gemm_quantizex: gemm_quantize generic map(                                                                                                                  
                WIDTH   => WIDTH(i),                                                                                                                                    
                NEURONS => NEURONS(i),                                                                                                                                  
                INPUTS  => INPUTS(i),                                                                                                                                   
                                                                                                                                                                        
                Z2      => input_zeropoint(i),                                                                                                                          
                Z3      => output_zeropoint(i),                                                                                                                         
                M0      => M0(i),                                                                                                                                       
                n       => n(i),                                                                                                                                        
                a2z1      => a2z1(i)                                                                                                                                        
            )                                                                                                                                                           
            port map(                                                                                                                                                   
                clk     => clk, --clock_out_s,                                                                                                                          
                enable  => done_gemm_mult(i),                                                                                                                           
                reset   => reset,                                                                                                                                       
                                                                                                                                                                        
                input   => output_gemm_mult(i)(2*WIDTH(i)*NEURONS(i) -1 downto 0),                                                                                      
                                                                                                                                                                        
                output  => output_gemm_quant(i)(WIDTH(i)*NEURONS(i) -1 downto 0),                                                                                       
                done    => done_gemm_quant(i)                                                                                                                           
            );                                                                                                                                                          
                                                                                                                                                                        
            relux: relu generic map(                                                                                                                                    
                WIDTH   => WIDTH(i),                                                                                                                                    
                NEURONS => NEURONS(i),                                                                                                                                  
                threshold => relu_threshold(i)                                                                                                                          
            )                                                                                                                                                           
            port map(                                                                                                                                                   
                clk     => clk, --clock_out_s,                                                                                                                          
                enable  => done_gemm_quant(i),                                                                                                                          
                reset   => reset,                                                                                                                                       
                                                                                                                                                                        
                input   => output_gemm_quant(i)(WIDTH(i)*NEURONS(i) -1 downto 0),                                                                                       
                                                                                                                                                                        
                output  => output,                                                                                                                                      
                done    => done                                                                                                                                         
            );                                                                                                                                                          
        end generate LAST_LAYER;                                                                                                                                        
    end generate GEN_0;                                                                                                                                                 
                                                                                                                                                                        
                                                                                                                                                                        
end arch;                                                                                                                                                               
