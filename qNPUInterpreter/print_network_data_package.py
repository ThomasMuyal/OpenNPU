from decimalfraction_to_binary import decimalToBinary

def to_binary_signed(num, dtype):
    if dtype == 'int8':
        width = 8
    elif dtype == 'int16':
        width = 16
    elif dtype == 'int32':
        width = 32
    formatting_string = "0" + str(width) + "b"
    if num >= 0:
        return format(num, formatting_string)
    else:
        twos_comp = 2**width + num
        return format(twos_comp, formatting_string)

def to_binary_signed_bias(num, dtype):
    if dtype == 'int8':
        width = 16
    elif dtype == 'int16':
        width = 32
    elif dtype == 'int32':
        width = 64
    formatting_string = "0" + str(width) + "b"
    if num >= 0:
        return format(num, formatting_string)
    else:
        twos_comp = 2**width + num
        return format(twos_comp, formatting_string)


def print_network_data_package(node_to_node_operations, node_to_node_inputs, gemms):

    filename = "network_data_package.vhd"
    f = open(filename, "w")
    
    # Writes header
    filebuffer = [
       "library IEEE;",
       "use IEEE.STD_LOGIC_1164.ALL;",
       "use IEEE.NUMERIC_STD.ALL;",
       "use IEEE.FIXED_PKG.ALL;"
       "",
       "package network_data_package is ",
    ]
    
    f.writelines("%s\n" % line for line in filebuffer)
    layers = 0

    # Declares int_array_layer_t datatype according to number of layers
    f.write("   constant LAYERS     : integer := " + str(len(gemms)) + ";\n")
    filebuffer = [
        "   type int_array_layer_t is array(0 to LAYERS-1) of integer;",
        "   type ufixed_array_layer_t is array(0 to LAYERS-1) of ufixed(-1 downto -32);",
    ]
    
    f.writelines("%s\n" % line for line in filebuffer)
    # Declares constant WIDTH according to layer weight datatype
    max_width = 0
    f.write("   constant WIDTH      : int_array_layer_t := (")
    for i in range(len(gemms)-1 , -1, -1):
        dtype = gemms[i].dtype
        if dtype == 'int8':
            f.write("8")
            if max_width < 8:
                max_width = 8
        elif dtype == 'int16':
            f.write("16")
            if max_width < 16:
                max_width = 16
        elif dtype == 'int32':
            f.write("32")
            if max_width < 32:
                max_width = 32
        else:
            f.write("layer has unsupported datatype")
        if i != 0:
            f.write(", ")
    f.write(");\n")

    # Declares constant NEURONS according to amount of neurons in each layer 
    #   Number of neurons is obtained by analysing weight matrix dimensions (inputs x neurons)
    max_neurons = 0
    f.write("   constant NEURONS    : int_array_layer_t := (")
    for i in range (len(gemms)-1 , -1, -1):
        f.write(str(gemms[i].n_neurons))
        if gemms[i].n_neurons > max_neurons:
            max_neurons = gemms[i].n_neurons
        if i != 0:
            f.write(", ")
    f.write(");\n")

    # Declares constant INPUTS according to number of inputs for each layer
    #   Number of inputs is obtained by analysing weight matrix dimensions (inputs x neurons)
    max_inputs = 0
    f.write("   constant INPUTS     : int_array_layer_t := (")
    for i in range (len(gemms)-1 , -1, -1):
        f.write(str(gemms[i].n_inputs))
        if gemms[i].n_inputs > max_inputs:
            max_inputs = gemms[i].n_inputs
        if i != 0:
            f.write(", ")
    f.write(");\n")
    
    f.write("   constant max_WIDTH     : integer := " + str(max_width) + ";\n")
    f.write("   constant max_NEURONS     : integer := " + str(max_neurons) + ";\n")
    f.write("   constant max_INPUTS     : integer := " + str(max_inputs) + ";\n")
    # Writes useful comment 
    filebuffer = [
    "-- arrays for storing weights and bias are jagged, ",
    "--   as they are dependant on each layer's width, neurons and inputs",
    "-- vhdl does not support jagged arrays, as such they will be defined ",
    "--   having the maximum required length, and the synthesis tool should",
    "--   trim the signals in implementation",
    "",
    "-- bias uses double precision"
    ]
    # Declares useful datatypes to store all the weights and bias values under their respective constants
    f.writelines("%s\n" % line for line in filebuffer)
    f.write("   type array_maxparameters_t is array(0 to LAYERS-1) of STD_LOGIC_VECTOR(")
    f.write(str(max_inputs) + "*" + str(max_neurons) + "*" + str(max_width)+ "-1 downto 0);\n")

    f.write("   type array_bias_maxparameters_t is array(0 to LAYERS-1) of STD_LOGIC_VECTOR(")
    f.write("2*" + str(max_neurons) + "*" + str(max_width)+ "-1 downto 0);\n")
    
    weight_leadingzeros = max_inputs*max_neurons*max_width
    bias_leadingzeros = 2*max_neurons*max_width
    # Stores weight values. Each weights(n) corresponds to all of the nth layer's concatenated weight values 
    f.write("   constant weights : array_maxparameters_t := (")
    for i in range (len(gemms)-1 , -1, -1):
        f.write("\"")
        if dtype == 'int8':
            width = 8
        elif dtype == 'int16':
            width = 16
        elif dtype == 'int32':
            width = 32
        for j in range(weight_leadingzeros-(width*gemms[i].n_neurons*gemms[i].n_inputs)):
            f.write("0")
        for neuron_iterator in range (gemms[i].n_neurons-1, -1, -1):
            for input_iterator in range (gemms[i].n_inputs-1, -1, -1):
                f.write(to_binary_signed(gemms[i].weights[input_iterator][neuron_iterator], gemms[i].dtype))
        f.write("\"")
        if i != 0:
            f.write(", ")  
    f.write(");\n")

    # Stores bias values. 
    # todo: If layer doesnt use bias, store 0s
    f.write("   constant bias    : array_bias_maxparameters_t := (")
    for i in range (len(gemms)-1 , -1, -1):
        f.write("\"")
        if dtype == 'int8':
            width = 8
        elif dtype == 'int16':
            width = 16
        elif dtype == 'int32':
            width = 32
        for j in range(bias_leadingzeros-(2*width*gemms[i].n_neurons)):
            f.write("0")
        for neuron_iterator in range (gemms[i].n_neurons-1, -1, -1):
            
            f.write(to_binary_signed_bias(gemms[i].bias[neuron_iterator], gemms[i].dtype))
        f.write("\"")
        if i != 0:
            f.write(", ")
    f.write(");\n\n")

    f.write("   type array_done_t is array(0 to LAYERS-1) of STD_LOGIC_VECTOR(7 downto 0);\n")

    f.write("   type array_output_t is array(0 to LAYERS-1) of STD_LOGIC_VECTOR(");
    f.write("max_NEURONS*max_WIDTH")
    f.write(" -1 downto 0);\n")

    f.write("   type array_double_output_t is array(0 to LAYERS-1) of STD_LOGIC_VECTOR(")
    f.write("2*max_NEURONS*max_WIDTH")
    f.write(" -1 downto 0);\n\n")

    f.write("   type a2z1_array   is array(0 to max_NEURONS-1) of integer;\n")
    f.write("   type a2z1_matrix  is array(0 to LAYERS-1) of a2z1_array;\n\n")

    # Stores the quantized layers' quantization parameters
    f.write("   -- quantization parameters\n")

    # Input zeropoints
    f.write("   constant input_zeropoint  : int_array_layer_t := (")
    for i in range(len(gemms)-1 , -1, -1):
        f.write(str(gemms[i].input_zero))
        if i != 0:
            f.write(", ")
    f.write(");\n")

    # Output zeropoints
    f.write("   constant output_zeropoint : int_array_layer_t :=  (")
    for i in range(len(gemms)-1 , -1, -1):
        f.write(str(gemms[i].output_zero))
        if i != 0:
            f.write(", ")
    f.write(");\n")
    f.write("   constant relu_threshold : int_array_layer_t := (")
    for i in range(len(gemms)-1 , -1, -1):
        f.write(str(gemms[i].output_zero))
        if i != 0:
            f.write(", ")
    f.write(");\n")

    # a2z1 constant
    f.write("   constant a2z1         : a2z1_matrix := ((")
    for i in range(len(gemms)-1 , -1, -1):
        for neuron_iterator in range(gemms[i].n_neurons):
            a2 = 0
            for input_iterator in range(gemms[i].n_inputs):
                a2 += gemms[i].weights[input_iterator][neuron_iterator]
            a2z1 = (-1)*a2*gemms[i].input_zero
            f.write(str(a2z1))
            if neuron_iterator != gemms[i].n_neurons -1:
                f.write(", ")
        if gemms[i].n_neurons < max_neurons:
            f.write(", ")
            for j in range(max_neurons - gemms[i].n_neurons):
                f.write("0")
                if j != max_neurons - gemms[i].n_neurons -1:
                    f.write(", ")
        if i != 0:
            f.write("), (")
        
    f.write("));\n\n")

    # M0 and n
    n = {}
    M0 = {}
    for i in range(len(gemms)-1, -1, -1):
        M = gemms[i].input_scale * gemms[i].weight_scale / gemms[i].output_scale
        n[i] = 0
        while M * pow(2, n[i]) < 0.5:
            n[i] += 1
        M0[i] = M * pow(2, n[i])


    f.write("   constant n               : int_array_layer_t := (")
    for i in range(len(gemms)-1, -1, -1):
        f.write(str(n[i]))
        if i != 0:
            f.write(", ")
    f.write(");\n")

    f.write("   constant M0               : ufixed_array_layer_t := (")
    for i in range(len(gemms)-1, -1, -1):
        f.write("\"" + decimalToBinary(M0[i], 32) + "\"")
        #f.write(to_binary_signed(M0[i], 'int32'))
        if i != 0:
            f.write(", ")
    f.write(");\n")

    



    #todo: calc M0 and n
    # M = S1 * S2 / S3
    # n is positive integer such M0 is in the interval [0.5, 1.0), such as that M0 * 2^(-n) = M
    # M0 = M / 2^(-n)
    # M0 = M * 2^(n)

    f.write("end package network_data_package;")
    f.close()

