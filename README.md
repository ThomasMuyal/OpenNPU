# OpenQNPU

OpenQNPU is an automatic generation workflow that, using a trained neural network model, automatically writes VHDL code for a hardware accelerator that optimizes its execution that can be synthesized in an FPGA.
The accelerator aims to increase execution speed and energy efficiency in such a way as it may be implemented in a Internet of Things embedded system low-power context. As such, the system is compatible with the Tensorflow Lite's quantization scheme, and includes the necessary quantized arithmetic corrections.

This is a proof-of-concept created to verify the project's feasibility, with limited functionality.
The system was designed modularly, to facilitate the expansion of its functionality by the community.

The top-level environment file of the program is qNPUInterpreter.py, which is executable. This file imports files that help interpret the loaded neural network, and files that print the resulting VHDL code.

The interpreter converts the model into the ONNX format and examines the ONNX graphs nodes. From the node operations, the interpreter calls the necessary print functions to print the VHDL files.
Furthermore, the interpreter reads constants such as weights, biases, number of layers and neurons, and writes a "network_data_package" file, which is used during VHDL compilation to generate the final topology.

The final VHDL consists in the following structure:
* The top-level file, "top_datapath", which generates the components corresponding to the network's layers, and calls the network data package;
* The network data package, "network_data_package.vhd";
* Files corresponding to the activation function components, such as "relu.vhd";
* Files corresponding to the layer's connectivity rules, such as "gemm_mult.vhd";
* Files corresponding to quantization corrections, such as "gemm_quantize.vhd".

## Using the interpreter
1. Execute the qNPUInterpreter.py file;
2. Select the neural network exported model file to interpret (see Compatibility for compatible model representations);
3. The script will write .vhd files corresponding to the selected neural network;
4. Compile the .vhd files using "top_datapath.vhd" as the top-level entity, enabling VHDL-2008

## Including new activation functions
To include a new activation function, the following is necessary:
1. A .py file that prints a VHDL file that implements the function;
2. Modify the qNPUInterpreter.py file to include the new operation in the "synthesizable_operations" list;
3. Modify the qNPUInterpreter.py to include the new print file, and to call the new print file if the new operation is found in the interpreted model.

Note that as a design pattern, the new activation function is then used as a component in a top-level VHDL entity. Furthermore, the relevant variables, such as weights, are left as GENERIC, and written during VHDL compilation using the network_data_package. Consult print_relu.py and relu.vhd for examples.

## Including new topologies
To include new topologies, the following is necessary:
1. A .py file that prints a new multiplication .vhd file must be written;
2. The printDatapathv2.py must be modified to include the new multiplication;
3. The qNPUInterpreter.py must be modified to detect the new topology and call printDatapathv2.py accordingly.

The gemm_mult.vhd file consists in a component that multiplies matrices corresponding to all of a layer's weights and neuron inputs, as well as adding the bias, when present. The printGemmv2.py corresponds to a matrix multiplication that implements the fully connected layer topology, that is, each of the current layer's neurons has all of the previous layer's outputs as inputs, each multiplied by its own weight.


## Compatibility
Compatible neural network activation functions:
1. Rectified Linear Unit (ReLU)

Compatible neural network topologies:
1. Fully connected (Dense) layers 

Compatible neural network model representations:
1. Tensorflow Lite
