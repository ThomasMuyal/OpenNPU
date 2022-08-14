library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use IEEE.FIXED_PKG.ALL;
package network_data_package is 
   constant LAYERS     : integer := 2;
   type int_array_layer_t is array(0 to LAYERS-1) of integer;
   type ufixed_array_layer_t is array(0 to LAYERS-1) of ufixed(-1 downto -32);
   constant WIDTH      : int_array_layer_t := (8, 8);
   constant NEURONS    : int_array_layer_t := (3, 1);
   constant INPUTS     : int_array_layer_t := (2, 3);
   constant max_WIDTH     : integer := 8;
   constant max_NEURONS     : integer := 3;
   constant max_INPUTS     : integer := 3;
-- arrays for storing weights and bias are jagged, 
--   as they are dependant on each layer's width, neurons and inputs
-- vhdl does not support jagged arrays, as such they will be defined 
--   having the maximum required length, and the synthesis tool should
--   trim the signals in implementation

-- bias uses double precision
   type array_maxparameters_t is array(0 to LAYERS-1) of STD_LOGIC_VECTOR(3*3*8-1 downto 0);
   type array_bias_maxparameters_t is array(0 to LAYERS-1) of STD_LOGIC_VECTOR(2*3*8-1 downto 0);
   constant weights : array_maxparameters_t := ("000000000000000000000000110110111010100110100000010111110111101010000001", "000000000000000000000000000000000000000000000000110000100111111101100001");
   constant bias    : array_bias_maxparameters_t := ("000000000000000011111110001011110000000000101010", "000000000000000000000000000000001111111111011101");

   type array_done_t is array(0 to LAYERS-1) of STD_LOGIC_VECTOR(7 downto 0);
   type array_output_t is array(0 to LAYERS-1) of STD_LOGIC_VECTOR(max_NEURONS*max_WIDTH -1 downto 0);
   type array_double_output_t is array(0 to LAYERS-1) of STD_LOGIC_VECTOR(2*max_NEURONS*max_WIDTH -1 downto 0);

   type a2z1_array   is array(0 to max_NEURONS-1) of integer;
   type a2z1_matrix  is array(0 to LAYERS-1) of a2z1_array;

   -- quantization parameters
   constant input_zeropoint  : int_array_layer_t := (-128, -81);
   constant output_zeropoint : int_array_layer_t :=  (-81, -79);
   constant relu_threshold : int_array_layer_t := (-81, -79);
   constant a2z1         : a2z1_matrix := ((-640, -128, -15872), (13122, 0, 0));

   constant n               : int_array_layer_t := (7, 6);
   constant M0               : ufixed_array_layer_t := ("10110010001001111111000111010011", "10100100110000100000101011111110");
end package network_data_package;